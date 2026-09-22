import asyncio
import gzip
import inspect
import json
import logging
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable

import httpx

logger = logging.getLogger(__name__)

MANIFEST_FILENAME: str = "manifest.json"
DEFAULT_MANIFEST_URL = (
    "https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/assets/manifest.json"
)
FALLBACK_MANIFEST_URLS: list[str] = [
    "https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/manifest.json",
    "https://raw.githubusercontent.com/Lucas2Araujo/Hin-rio_txt/main/manifest.json",
]


# Mapeamento padrão caso o manifesto ainda não esteja carregado
DEFAULT_MODULE_EXTENSIONS: dict[str, str] = {
    "hinario": ".db",
    "hinario_antigo": ".db",
    "hinario_comparativo": ".db",
}

BIBLE_MODULE_IDS: set[str] = {
    "ACF",
    "ARA",
    "ARC",
    "AS21",
    "BBE",
    "BKJ",
    "JFAA",
    "KJA",
    "KJF",
    "KJV",
    "MSGF",
    "NAA",
    "NBV",
    "NTLH",
    "NVI",
    "NVT",
    "TB",
    "VFL",
}


def _save_manifest_cache_sync(cache_file: Path, data: dict[str, Any]) -> None:
    """Grava o manifesto no cache local em disco em formato JSON."""
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


class ContentManager:
    """
    Gerenciador assíncrono responsável pelo ciclo de vida de módulos on-demand (Bíblias e Hinários).
    - Localização e criação do diretório gravável de módulos
    - Busca e cache local do manifest.json
    - Download em streaming com barra de progresso
    - Descompactação gzip (.gz -> .sqlite/.db)
    - Verificação de status de instalação e exclusão de módulos
    - Atualização no client_storage do Flet
    """

    def __init__(
        self,
        modules_dir: Path | str | None = None,
        manifest_url: str = DEFAULT_MANIFEST_URL,
    ):
        self._custom_modules_dir = Path(modules_dir) if modules_dir else None
        self.manifest_url = manifest_url
        self._manifest_cache: dict[str, Any] | None = None
        self._active_downloads: dict[str, asyncio.Event] = {}
        self._installed_modules_cache: dict[str, bool] | None = None
        self._installed_bibles_cache: list[str] | None = None

    @staticmethod
    def _get_android_storage_dir() -> Path | None:
        """Tenta resolver o diretório de módulos em ambiente Android."""
        for env_var in ["FLET_APP_STORAGE_DATA", "FILES_DIR", "ANDROID_PRIVATE"]:
            val = os.environ.get(env_var)
            if val:
                p = Path(val) / "modules"
                try:
                    p.mkdir(parents=True, exist_ok=True)
                    if os.access(p, os.W_OK):
                        return p
                except Exception:
                    pass
        return None

    @staticmethod
    def _get_desktop_modules_dir() -> Path | None:
        """Determina o diretório padrão de dados da aplicação em sistemas Desktop."""
        try:
            if sys.platform.startswith("win"):
                base = Path(os.environ.get("APPDATA", Path.home()))
                p = base / "HinarioApp" / "modules"
            elif sys.platform == "darwin":
                p = Path.home() / "Library" / "Application Support" / "HinarioApp" / "modules"
            else:
                home = Path.home()
                if str(home) == "/data" or not os.access(home, os.W_OK):
                    base = Path(tempfile.gettempdir())
                else:
                    base = Path(
                        os.environ.get("XDG_DATA_HOME", home / ".local" / "share")
                    )
                p = base / "hinario_app" / "modules"

            p.mkdir(parents=True, exist_ok=True)
            if os.access(p, os.W_OK):
                return p
        except Exception:
            pass
        return None

    @classmethod
    def get_modules_dir(cls, custom_dir: Path | str | None = None) -> Path:
        """
        Determina o diretório gravável seguro para armazenar os módulos baixados.
        Compatível com Android (serious_python/Flet), Desktop (Linux, Windows, macOS) e testes.
        """
        if custom_dir:
            p = Path(custom_dir)
            p.mkdir(parents=True, exist_ok=True)
            return p

        # 1. Variável de ambiente explícita
        env_dir = os.environ.get("HINARIO_MODULES_DIR")
        if env_dir:
            p = Path(env_dir)
            p.mkdir(parents=True, exist_ok=True)
            return p

        # 2. Variáveis de ambiente Android / Flet
        android_dir = cls._get_android_storage_dir()
        if android_dir:
            return android_dir

        # 3. Diretório de usuário padrão da plataforma (Desktop)
        desktop_dir = cls._get_desktop_modules_dir()
        if desktop_dir:
            return desktop_dir

        # 4. Fallback no diretório temporário
        p = Path(tempfile.gettempdir()) / "hinario_app" / "modules"
        p.mkdir(parents=True, exist_ok=True)
        return p

    @property
    def modules_dir(self) -> Path:
        """Retorna o diretório de módulos desta instância."""
        return self.get_modules_dir(self._custom_modules_dir)

    def _find_bundled_manifest(self) -> Path | None:
        """Procura o manifest.json embutido nos assets ou na raiz do projeto (excluindo cache)."""
        module_dir = Path(__file__).resolve().parent
        candidates = [
            module_dir.parent.parent / "assets" / MANIFEST_FILENAME,
            module_dir.parent.parent / MANIFEST_FILENAME,
            module_dir.parent / "assets" / MANIFEST_FILENAME,
            Path.cwd() / "assets" / MANIFEST_FILENAME,
            Path.cwd() / MANIFEST_FILENAME,
        ]
        for c in candidates:
            if c.exists() and c.is_file() and c.stat().st_size > 0:
                return c.resolve()
        return None

    def _read_cached_or_bundled_manifest(self) -> dict[str, Any] | None:
        """
        Lê o manifesto comparando o cache local em disco com o arquivo embutido.
        Retorna o que possuir a maior versão para garantir que atualizações do app
        sobreponham caches antigos obsoletos.
        """
        bundled_data: dict[str, Any] | None = None
        bundled_path = self._find_bundled_manifest()
        if bundled_path:
            try:
                with open(bundled_path, "r", encoding="utf-8") as f:
                    bundled_data = json.load(f)
            except Exception as exc:
                logger.warning("Erro ao ler manifesto embutido %s: %s", bundled_path, exc)

        cached_data: dict[str, Any] | None = None
        cache_file = self.modules_dir / MANIFEST_FILENAME
        if cache_file.exists() and cache_file.is_file() and cache_file.stat().st_size > 0:
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cached_data = json.load(f)
            except Exception as exc:
                logger.warning("Erro ao ler cache do manifesto %s: %s", cache_file, exc)

        if bundled_data and cached_data:
            # Compara versões semânticas ou inteiras dos manifestos
            b_ver = int(bundled_data.get("version", 1))
            c_ver = int(cached_data.get("version", 1))
            if b_ver > c_ver:
                return bundled_data
            return cached_data

        return bundled_data or cached_data

    async def get_manifest(self, force_refresh: bool = False) -> dict[str, Any]:
        """
        Obtém o manifesto de módulos, buscando da URL remota via httpx (com fallbacks)
        com fallback automático para o cache local em disco ou asset embutido.
        """
        if not force_refresh and self._manifest_cache:
            return self._manifest_cache

        remote_data: dict[str, Any] | None = None
        urls_to_try = [self.manifest_url]
        if self.manifest_url == DEFAULT_MANIFEST_URL:
            for fb_url in FALLBACK_MANIFEST_URLS:
                if fb_url not in urls_to_try:
                    urls_to_try.append(fb_url)

        for url in urls_to_try:
            try:
                async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
                    response = await client.get(url)
                    if response.status_code == 200:
                        parsed = response.json()
                        if isinstance(parsed, dict) and "modules" in parsed:
                            remote_data = parsed
                            break
            except Exception as exc:
                logger.debug("Falha ao buscar manifesto remoto (%s): %s", url, exc)

        if remote_data and isinstance(remote_data, dict) and "modules" in remote_data:
            self._manifest_cache = remote_data
            try:
                cache_file = self.modules_dir / MANIFEST_FILENAME
                await asyncio.to_thread(_save_manifest_cache_sync, cache_file, remote_data)
            except Exception as e:
                logger.warning(f"Não foi possível salvar cache do manifesto: {e}")
            return remote_data

        # Fallback para cache local / arquivo embutido
        local_data = self._read_cached_or_bundled_manifest()
        if local_data:
            self._manifest_cache = local_data
            return local_data

        return {"version": 1, "modules": []}

    def get_module_target_filename(self, module_info_or_id: dict[str, Any] | str) -> str:
        """Retorna o nome do arquivo descompactado correspondente ao módulo (.sqlite ou .db)."""
        if isinstance(module_info_or_id, dict):
            file_name = module_info_or_id.get("file", "")
            if file_name.endswith(".gz"):
                return file_name[:-3]
            if file_name:
                return file_name
            mod_id = module_info_or_id.get("id", "")
        else:
            mod_id = module_info_or_id

        ext = DEFAULT_MODULE_EXTENSIONS.get(mod_id, ".sqlite")
        return f"{mod_id}{ext}"

    def _find_seed_module(self, filename: str) -> Path | None:
        """Busca arquivo de dados semente embutido no projeto."""
        module_dir = Path(__file__).resolve().parent
        candidates = [
            module_dir.parent / "database" / "data" / filename,
            module_dir.parent / "database" / "data" / "biblias" / filename,
            module_dir.parent.parent / "assets" / filename,
            module_dir.parent.parent / "assets" / "biblias" / filename,
            module_dir.parent.parent / "src" / "database" / "data" / filename,
            module_dir.parent.parent / "src" / "database" / "data" / "biblias" / filename,
            Path.cwd() / "assets" / filename,
            Path.cwd() / "assets" / "biblias" / filename,
            Path.cwd() / "src" / "database" / "data" / filename,
            Path.cwd() / "src" / "database" / "data" / "biblias" / filename,
        ]
        for c in candidates:
            if c.exists() and c.is_file() and c.stat().st_size > 0:
                return c.resolve()
        return None

    def get_module_path(self, module_id: str) -> Path | None:
        """
        Retorna o Path do arquivo do módulo caso esteja instalado no diretório gravável,
        ou None caso não esteja presente. Se for hinario_antigo ou bíblia padrão e houver seed local,
        realiza o auto-seeding seguro.
        """
        target_name = self.get_module_target_filename(module_id)
        target_path = self.modules_dir / target_name
        if target_path.exists() and target_path.stat().st_size > 0:
            return target_path

        # Verifica também se está em subpasta 'biblias'
        alt_path = self.modules_dir / "biblias" / target_name
        if alt_path.exists() and alt_path.stat().st_size > 0:
            return alt_path

        # Se for hinario_antigo e existir semente válida embutida (Desktop / dev / assets), faz auto-seed
        if module_id == "hinario_antigo":
            seed = self._find_seed_module(target_name)
            if seed and seed.exists() and seed.stat().st_size > 0:
                try:
                    self.modules_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(seed, target_path)
                    if target_path.exists() and target_path.stat().st_size > 0:
                        return target_path
                except Exception as e:
                    logger.debug("Falha ao semear hinario_antigo: %s", e)
                    return seed

        return None

    def is_module_outdated(
        self, module_id: str, module_info: dict[str, Any] | None = None
    ) -> bool:
        """
        Verifica se um módulo instalado localmente está desatualizado.
        Para 'hinario_antigo': verifica se faltam links de vídeo populados na tabela hino.
        """
        mod_path = self.get_module_path(module_id)
        if not mod_path or not mod_path.exists():
            return False

        if module_id == "hinario_antigo":
            try:
                import sqlite3
                conn = sqlite3.connect(f"file:{mod_path}?mode=ro", uri=True)
                cur = conn.cursor()
                cur.execute("PRAGMA table_info(hino)")
                cols = [c[1] for c in cur.fetchall()]
                if "link_video" not in cols:
                    conn.close()
                    return True
                cur.execute(
                    "SELECT COUNT(*) FROM hino WHERE link_video IS NOT NULL AND TRIM(link_video) != ''"
                )
                count = cur.fetchone()[0]
                conn.close()
                if count == 0:
                    return True
            except Exception as exc:
                logger.debug("Erro ao verificar se hinario_antigo está desatualizado: %s", exc)

        return False


    def invalidate_cache(self) -> None:
        """Invalida o cache em memória de módulos e Bíblias instaladas."""
        self._installed_modules_cache = None
        self._installed_bibles_cache = None

    def is_module_installed(self, module_id: str) -> bool:
        """Verifica se o módulo correspondente está instalado e não corrompido (tamanho > 0)."""
        if self._installed_modules_cache is not None and module_id in self._installed_modules_cache:
            return self._installed_modules_cache[module_id]

        installed = self.get_module_path(module_id) is not None
        if self._installed_modules_cache is None:
            self._installed_modules_cache = {}
        self._installed_modules_cache[module_id] = installed
        return installed

    def has_any_bible_installed(self) -> bool:
        """Informa se ao menos uma versão completa da Bíblia está instalada localmente."""
        return len(self.get_installed_bible_ids()) > 0

    def get_installed_bible_ids(self) -> list[str]:
        """Retorna a lista de IDs das Bíblias completas instaladas localmente."""
        if self._installed_bibles_cache is not None:
            return list(self._installed_bibles_cache)

        installed = []
        for bid in sorted(BIBLE_MODULE_IDS):
            if self.is_module_installed(bid):
                installed.append(bid)
        self._installed_bibles_cache = installed
        return list(installed)

    async def _report_progress(
        self, callback: Callable[[float], Any] | None, val: float
    ) -> None:
        """Executa callback de progresso suportando funções síncronas e corrotinas."""
        if not callback:
            return
        try:
            if inspect.iscoroutinefunction(callback):
                await callback(val)
            else:
                res = callback(val)
                if asyncio.iscoroutine(res):
                    await res
        except Exception:
            pass

    async def _stream_chunks_to_file(
        self,
        response: httpx.Response,
        tmp_gz_path: Path,
        expected_size: int,
        cancel_event: asyncio.Event,
        mod_id: str,
        on_progress: Callable[[float], Any] | None,
    ) -> None:
        """Grava os chunks HTTP baixados no arquivo temporário assincronamente com cálculo de progresso."""
        downloaded_bytes = 0
        with open(tmp_gz_path, "wb") as f_tmp:
            async for chunk in response.aiter_bytes(chunk_size=65536):
                if cancel_event.is_set():
                    raise asyncio.CancelledError(
                        f"Download de {mod_id} cancelado pelo usuário."
                    )
                f_tmp.write(chunk)
                downloaded_bytes += len(chunk)
                if expected_size > 0:
                    ratio = min(0.95, (downloaded_bytes / expected_size) * 0.95)
                    await self._report_progress(on_progress, ratio)

    @staticmethod
    async def _update_client_storage_installed(
        page: Any | None, mod_id: str, installed: bool
    ) -> None:
        """Atualiza a flag de instalação do módulo no client_storage do Flet."""
        if not page or not hasattr(page, "client_storage") or not page.client_storage:
            return
        key = f"module_{mod_id}_installed"
        try:
            await page.client_storage.set_async(key, installed)
        except Exception:
            try:
                page.client_storage.set(key, installed)
            except Exception:
                pass

    async def download_module(
        self,
        module_info: dict[str, Any],
        on_progress: Callable[[float], Any] | None = None,
        page: Any | None = None,
    ) -> Path:
        """
        Baixa o módulo via streaming HTTP com httpx, salva como arquivo temporário .tmp.gz,
        reporta progresso via on_progress(float), descompacta via gzip nativo para o formato
        final (.sqlite ou .db) e atualiza o client_storage.
        """
        mod_id = module_info.get("id", "unknown")
        url = module_info.get("url")
        if not url:
            raise ValueError(f"URL de download ausente para o módulo {mod_id}")

        final_filename = self.get_module_target_filename(module_info)
        target_path = self.modules_dir / final_filename
        tmp_gz_path = self.modules_dir / f"{final_filename}.tmp.gz"

        cancel_event = asyncio.Event()
        self._active_downloads[mod_id] = cancel_event

        expected_size = int(module_info.get("size_bytes") or 0)
        await self._report_progress(on_progress, 0.0)

        try:
            async with httpx.AsyncClient(timeout=60.0, follow_redirects=True) as client:
                async with client.stream("GET", url) as response:
                    response.raise_for_status()
                    total_header = response.headers.get("content-length")
                    if total_header and total_header.isdigit():
                        expected_size = int(total_header)

                    await self._stream_chunks_to_file(
                        response, tmp_gz_path, expected_size, cancel_event, mod_id, on_progress
                    )

            # Notifica descompactação e descompacta em thread
            await self._report_progress(on_progress, 0.96)
            await asyncio.to_thread(self._decompress_gzip, tmp_gz_path, target_path)

            if tmp_gz_path.exists():
                try:
                    tmp_gz_path.unlink()
                except OSError:
                    pass

            await self._update_client_storage_installed(page, mod_id, True)
            self.invalidate_cache()
            await self._report_progress(on_progress, 1.0)
            return target_path

        except Exception:
            if tmp_gz_path.exists():
                try:
                    tmp_gz_path.unlink()
                except OSError:
                    pass
            raise
        finally:
            self._active_downloads.pop(mod_id, None)

    @staticmethod
    def _decompress_gzip(src_gz: Path, dest_file: Path) -> None:
        """Descompacta um arquivo .gz para o destino final em blocos seguros de memória."""
        temp_dest = Path(f"{dest_file}.extracting")
        with gzip.open(src_gz, "rb") as f_in, open(temp_dest, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out, length=131072)
        if dest_file.exists():
            dest_file.unlink()
        temp_dest.rename(dest_file)

    def cancel_download(self, module_id: str) -> bool:
        """Sinaliza cancelamento para um download ativo."""
        if module_id in self._active_downloads:
            self._active_downloads[module_id].set()
            return True
        return False

    @staticmethod
    def _remove_sqlite_files(target_path: Path) -> None:
        """Remove o arquivo de banco de dados SQLite e quaisquer arquivos auxiliares (-wal, -shm, -journal)."""
        for ext in ["-wal", "-shm", "-journal"]:
            aux = Path(f"{target_path}{ext}")
            if aux.exists():
                try:
                    aux.unlink()
                except OSError:
                    pass
        if target_path.exists():
            target_path.unlink()

    async def delete_module(self, module_id: str, page: Any | None = None) -> bool:
        """
        Exclui o arquivo do módulo correspondente e quaisquer arquivos auxiliares SQLite (-wal, -shm).
        Atualiza o client_storage.
        """
        target_name = self.get_module_target_filename(module_id)
        # Limpa também no user_dir se DatabaseConnection tiver copiado para lá
        try:
            from src.database.connection import DatabaseConnection
            user_data_path = DatabaseConnection._get_user_data_dir() / target_name
            if user_data_path.exists():
                self._remove_sqlite_files(user_data_path)
        except Exception as e:
            logger.debug("Falha ao limpar cópia do usuário para %s: %s", target_name, e)

        target_path = self.get_module_path(module_id)
        if not target_path or not target_path.exists():
            await self._update_client_storage_installed(page, module_id, False)
            self.invalidate_cache()
            return False

        try:
            self._remove_sqlite_files(target_path)
            await self._update_client_storage_installed(page, module_id, False)
            self.invalidate_cache()
            return True
        except Exception:
            logger.exception("Erro ao excluir módulo %s", module_id)
            raise

