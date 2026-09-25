import sqlite3
from typing import Any

from src.models.culto import ItemLiturgico, PlanoCulto, TipoItemLiturgico
from src.models.hino import Hino
from src.repositories.biblia_repository import BibliaRepository
from src.repositories.hino_repository import HinoRepository
from src.services.content_manager import ContentManager
from src.services.hino_recommender import HinoRecommender, ScoredHino

NOMES_BLOCOS_LITURGICOS = [
    "1. Abertura & Adoração",
    "2. Oração & Comunhão",
    "3. Louvor & Gratidão",
    "4. Mensagem & Edificação",
    "5. Reflexão & Meditação",
    "6. Consagração & Entrega",
    "7. Intercessão",
    "8. Testemunho & Partilha",
    "9. Esperança & Promessas",
    "10. Encerramento & Bênção",
]


class AgenteService:
    """
    Serviço assíncrono do Agente Organizador Litúrgico de Cultos.
    Realiza busca semântica, pontuação temática sobre os hinos (atuais e antigos),
    integra leituras bíblicas automáticas via SQLite e momentos de oração contextuais,
    montando uma ordem de culto polimórfica estruturada e determinística.
    """

    def __init__(
        self,
        hino_repository: HinoRepository,
        recommender: HinoRecommender | None = None,
        biblia_repository: BibliaRepository | None = None,
        content_manager: ContentManager | None = None,
    ):
        self.hino_repository = hino_repository
        self.recommender = recommender or HinoRecommender()
        self.biblia_repository = biblia_repository
        self.content_manager = content_manager
        # Cache in-memory de hinos completos por fonte para scoring
        self._hinos_completos_cache: dict[str, dict[int, Hino]] = {}

    async def _fetch_hinos_completos(self, fonte: str = "atual") -> dict[int, Hino]:
        """Busca todos os hinos com dados completos no repositório para uma fonte específica."""
        if hasattr(self.hino_repository, "get_all_complete"):
            try:
                all_hinos = await self.hino_repository.get_all_complete(fonte=fonte)
                return {h.id: h for h in all_hinos if h.id is not None}
            except TypeError:
                all_hinos = await self.hino_repository.get_all_complete()
                return {h.id: h for h in all_hinos if h.id is not None}

        # Fallback para repositórios sem get_all_complete
        try:
            all_hinos = await self.hino_repository.get_all(fonte=fonte)
        except TypeError:
            all_hinos = await self.hino_repository.get_all()

        result: dict[int, Hino] = {}
        for h in all_hinos:
            if h.id is None:
                continue
            try:
                hino = await self.hino_repository.get_by_id(h.id, fonte=fonte)
            except TypeError:
                hino = await self.hino_repository.get_by_id(h.id)
            if hino:
                result[h.id] = hino
        return result

    async def _get_hinos_completos(self, fonte: str = "atual") -> dict[int, Hino]:
        """Carrega e cacheia todos os hinos com campos completos para scoring."""
        if fonte not in self._hinos_completos_cache:
            self._hinos_completos_cache[fonte] = await self._fetch_hinos_completos(
                fonte=fonte
            )
        return self._hinos_completos_cache[fonte]

    async def _get_temas_por_hino(self, hino_id: int) -> list[str]:
        """Retorna os temas associados a um hino via tabela de junção."""
        metadados = await self.hino_repository.get_metadados_relacionados(hino_id)
        return metadados.get("temas", [])

    def _extrair_palavras_chave(self, prompt: str) -> list[str]:
        """Extrai palavras-chave relevantes utilizando o HinoRecommender."""
        return self.recommender.tokenize(prompt)

    async def _gerar_playlist_padrao(
        self, num_hinos: int, template: str = "geral", fonte: str = "atual"
    ) -> dict[str, Any]:
        """Gera uma liturgia padrão de adoração quando o prompt estiver vazio."""
        hinos = await self.hino_repository.search("Santo", fonte=fonte)
        hinos_selecionados = (
            hinos[:num_hinos]
            if len(hinos) >= num_hinos
            else await self.hino_repository.get_all(fonte=fonte)
        )
        scored_padrao = [
            ScoredHino(
                hino=h,
                score_total=0,
                reasons=[],
            )
            for h in hinos_selecionados[:num_hinos]
        ]
        return await self._montar_ordem_culto(
            tema="Culto Geral",
            scored_hinos=scored_padrao,
            template=template,
        )

    def _add_candidate_ids(
        self,
        candidatos: list[tuple[str, int]],
        vistos: set[tuple[str, int]],
        hinos: list[Hino],
        limite: int | None = None,
    ) -> None:
        """Adiciona tuplas (fonte, id) de hinos não duplicados à lista de candidatos."""
        for h in hinos:
            if h.id is not None:
                chave = (getattr(h, "fonte", "atual"), h.id)
                if chave not in vistos:
                    vistos.add(chave)
                    candidatos.append(chave)
                    if limite and len(candidatos) >= limite:
                        break

    async def _buscar_candidatos_ids(
        self, palavras_relevantes: list[str], num_hinos: int, fonte: str = "atual"
    ) -> list[tuple[str, int]]:
        """Busca tuplas (fonte, id) de hinos candidatos no repositório com base nas palavras-chave."""
        candidatos: list[tuple[str, int]] = []
        vistos: set[tuple[str, int]] = set()

        for kw in palavras_relevantes:
            resultados = await self.hino_repository.search(kw, fonte=fonte)
            self._add_candidate_ids(candidatos, vistos, resultados)

        # Complementa com hinos adicionais se houver poucos candidatos
        if len(candidatos) < num_hinos:
            todos = await self.hino_repository.get_all(fonte=fonte)
            self._add_candidate_ids(candidatos, vistos, todos, limite=num_hinos * 3)

        return candidatos

    async def _carregar_temas_candidatos(
        self, candidatos: list[tuple[str, int]]
    ) -> dict[int, list[str]]:
        """Carrega os temas dos hinos candidatos."""
        temas_por_hino: dict[int, list[str]] = {}
        for _, hino_id in candidatos[:40]:
            if hino_id not in temas_por_hino:
                temas_por_hino[hino_id] = await self._get_temas_por_hino(hino_id)
        return temas_por_hino

    async def _resolver_passagem_biblica(self, referencia: str) -> Any | None:
        """
        Busca uma passagem bíblica pelo texto_base no BibliaRepository se disponível.
        Retorna a PassagemBiblica encontrada ou None se não houver bíblia instalada/encontrada.
        """
        if not self.biblia_repository or not referencia:
            return None
        try:
            return await self.biblia_repository.buscar_passagem(referencia)
        except (sqlite3.Error, KeyError, ValueError, OSError):
            return None

    def _criar_momentos_oracao(self, tema: str) -> dict[str, ItemLiturgico]:
        """Cria os blocos de oração contextuais pré-estruturados."""
        invocacao = ItemLiturgico(
            ordem=0,
            tipo=TipoItemLiturgico.ORACAO,
            titulo_bloco="Oração de Abertura & Invocação",
            descricao_momento=(
                "Momento de abertura do culto: adoração ao Deus Todo-Poderoso, "
                "confissão, quebrantamento e convite à presença do Espírito Santo."
            ),
            conteudo="Oração silenciosa seguida de clamor pastoral de invocação.",
            metadados={"foco": "adoracao_invocacao"},
        )

        intercessao = ItemLiturgico(
            ordem=0,
            tipo=TipoItemLiturgico.ORACAO,
            titulo_bloco="Oração Pastoral & Intercessão",
            descricao_momento=(
                f"Momento de intercessão da comunidade dirigido pelo tema: '{tema}'. "
                "Súplicas pelas famílias, enfermos, liderança e fortalecimento espiritual."
            ),
            conteudo=f"Intercessão focalizada em '{tema}'.",
            metadados={"foco": "intercessao_tematica", "tema_direcionador": tema},
        )

        bencao = ItemLiturgico(
            ordem=0,
            tipo=TipoItemLiturgico.ORACAO,
            titulo_bloco="Bênção Final & Envio",
            descricao_momento=(
                "Encerramento da liturgia: proclamação da bênção apostólica, "
                "paz de Cristo e envio dos santos para o testemunho semanal."
            ),
            conteudo="Bênção apostólica solene de encerramento.",
            metadados={"foco": "bencao_final"},
        )

        return {
            "invocacao": invocacao,
            "intercessao": intercessao,
            "bencao": bencao,
        }

    async def _montar_ordem_culto(
        self,
        tema: str,
        scored_hinos: list[ScoredHino],
        template: str = "geral",
    ) -> dict[str, Any]:
        """
        Construtor polimórfico e flexível da ordem de culto por templates litúrgicos:
        - 'geral': Culto Geral / Solene
        - 'oracao': Culto de Oração & Intercessão
        - 'santa_ceia': Culto de Santa Ceia
        """
        oracoes = self._criar_momentos_oracao(tema)
        itens: list[ItemLiturgico] = []
        hinos_list: list[Hino] = [s.hino for s in scored_hinos]
        blocos_legados: list[dict[str, Any]] = []

        # Coleta referências bíblicas prioritárias a partir do texto_base dos melhores hinos
        refs_candidatas = [
            s.hino.texto_base
            for s in scored_hinos
            if s.hino.texto_base and s.hino.texto_base.strip()
        ]

        ref_abertura = refs_candidatas[0] if len(refs_candidatas) > 0 else None
        ref_sermon = (
            refs_candidatas[1]
            if len(refs_candidatas) > 1
            else (refs_candidatas[0] if refs_candidatas else None)
        )

        passagem_abertura = (
            await self._resolver_passagem_biblica(ref_abertura)
            if ref_abertura
            else None
        )
        passagem_sermon = (
            await self._resolver_passagem_biblica(ref_sermon)
            if ref_sermon
            else None
        )

        def make_hino_item(
            index: int, titulo: str, scored: ScoredHino
        ) -> ItemLiturgico:
            return ItemLiturgico(
                ordem=index,
                tipo=TipoItemLiturgico.HINO,
                titulo_bloco=titulo,
                descricao_momento=f"Louvor congregacional - Hino {scored.hino.numero}",
                conteudo=scored.hino,
                metadados={
                    "scored_hino": scored,
                    "score": scored.score_total,
                    "justificativa": scored.justificativa_legivel,
                    "fonte": getattr(scored.hino, "fonte", "atual"),
                },
            )

        # Montagem do template Litúrgico
        if template == "oracao":
            # Template Culto de Oração
            ordem_idx = 1
            # 1. Invocação
            inv = oracoes["invocacao"]
            inv.ordem = ordem_idx
            itens.append(inv)
            ordem_idx += 1

            # 2. Hino Inicial de Adoração
            if scored_hinos:
                itens.append(
                    make_hino_item(ordem_idx, "1. Hino de Preparação", scored_hinos[0])
                )
                ordem_idx += 1

            # 3. Leitura Bíblica Devocional
            if ref_abertura:
                itens.append(
                    ItemLiturgico(
                        ordem=ordem_idx,
                        tipo=TipoItemLiturgico.LEITURA_BIBLICA,
                        titulo_bloco="Leitura Bíblica Devocional",
                        descricao_momento=f"Texto base para meditação: {ref_abertura}",
                        conteudo=passagem_abertura or ref_abertura,
                        metadados={"referencia": ref_abertura},
                    )
                )
                ordem_idx += 1

            # 4. Hinos Intermediários
            for i, scored in enumerate(scored_hinos[1:-1], start=2):
                itens.append(
                    make_hino_item(
                        ordem_idx, f"{i}. Cântico de Comunhão", scored
                    )
                )
                ordem_idx += 1

            # 5. Oração Pastoral e Intercessão
            inter = oracoes["intercessao"]
            inter.ordem = ordem_idx
            itens.append(inter)
            ordem_idx += 1

            # 6. Hino Final e Bênção
            if len(scored_hinos) > 1:
                itens.append(
                    make_hino_item(
                        ordem_idx,
                        f"{len(scored_hinos)}. Hino de Consagração",
                        scored_hinos[-1],
                    )
                )
                ordem_idx += 1

            benc = oracoes["bencao"]
            benc.ordem = ordem_idx
            itens.append(benc)

        elif template == "santa_ceia":
            # Template Culto de Santa Ceia
            ordem_idx = 1
            inv = oracoes["invocacao"]
            inv.ordem = ordem_idx
            itens.append(inv)
            ordem_idx += 1

            if scored_hinos:
                itens.append(
                    make_hino_item(
                        ordem_idx, "1. Hino de Entrada e Reverência", scored_hinos[0]
                    )
                )
                ordem_idx += 1

            # Leitura Bíblica da Ceia (1 Coríntios 11 ou do hino)
            ref_ceia = ref_abertura or "1 Coríntios 11:23-26"
            passagem_ceia = (
                await self._resolver_passagem_biblica(ref_ceia)
                if ref_ceia
                else None
            )
            itens.append(
                ItemLiturgico(
                    ordem=ordem_idx,
                    tipo=TipoItemLiturgico.LEITURA_BIBLICA,
                    titulo_bloco="Leitura Bíblica da Instituição",
                    descricao_momento=f"Memorial do Senhor: {ref_ceia}",
                    conteudo=passagem_ceia or ref_ceia,
                    metadados={"referencia": ref_ceia},
                )
            )
            ordem_idx += 1

            # Hinos Intermediários / Distribuição dos Emblemas
            for i, scored in enumerate(scored_hinos[1:-1], start=2):
                itens.append(
                    make_hino_item(
                        ordem_idx, f"{i}. Louvor da Ceia do Senhor", scored
                    )
                )
                ordem_idx += 1

            inter = oracoes["intercessao"]
            inter.ordem = ordem_idx
            itens.append(inter)
            ordem_idx += 1

            if len(scored_hinos) > 1:
                itens.append(
                    make_hino_item(
                        ordem_idx,
                        f"{len(scored_hinos)}. Hino de Gratidão e Entrega",
                        scored_hinos[-1],
                    )
                )
                ordem_idx += 1

            benc = oracoes["bencao"]
            benc.ordem = ordem_idx
            itens.append(benc)

        else:
            # Template Culto Geral / Solene (Padrão)
            ordem_idx = 1

            # 1. Invocação
            inv = oracoes["invocacao"]
            inv.ordem = ordem_idx
            itens.append(inv)
            ordem_idx += 1

            # 2. Primeiro Hino (Abertura / Adoração)
            if scored_hinos:
                itens.append(
                    make_hino_item(
                        ordem_idx,
                        NOMES_BLOCOS_LITURGICOS[0],
                        scored_hinos[0],
                    )
                )
                ordem_idx += 1

            # 3. Leitura Bíblica de Abertura
            if ref_abertura:
                itens.append(
                    ItemLiturgico(
                        ordem=ordem_idx,
                        tipo=TipoItemLiturgico.LEITURA_BIBLICA,
                        titulo_bloco="Leitura Bíblica de Abertura",
                        descricao_momento=f"Leitura da Palavra: {ref_abertura}",
                        conteudo=passagem_abertura or ref_abertura,
                        metadados={"referencia": ref_abertura},
                    )
                )
                ordem_idx += 1

            # 4. Hinos Intermediários
            metade = max(1, len(scored_hinos) // 2)
            for i in range(1, metade):
                if i < len(scored_hinos):
                    nome_bloco = (
                        NOMES_BLOCOS_LITURGICOS[i]
                        if i < len(NOMES_BLOCOS_LITURGICOS)
                        else f"{i+1}. Louvor & Comunhão"
                    )
                    itens.append(
                        make_hino_item(ordem_idx, nome_bloco, scored_hinos[i])
                    )
                    ordem_idx += 1

            # 5. Oração Pastoral de Intercessão
            inter = oracoes["intercessao"]
            inter.ordem = ordem_idx
            itens.append(inter)
            ordem_idx += 1

            # 6. Leitura Pré-Sermão (se houver ref_sermon)
            if ref_sermon:
                itens.append(
                    ItemLiturgico(
                        ordem=ordem_idx,
                        tipo=TipoItemLiturgico.LEITURA_BIBLICA,
                        titulo_bloco="Leitura Pré-Sermão",
                        descricao_momento=f"Texto Bíblico da Pregação: {ref_sermon}",
                        conteudo=passagem_sermon or ref_sermon,
                        metadados={"referencia": ref_sermon},
                    )
                )
                ordem_idx += 1

            # 7. Momento da Pregação
            itens.append(
                ItemLiturgico(
                    ordem=ordem_idx,
                    tipo=TipoItemLiturgico.PREGACAO,
                    titulo_bloco="Mensagem Pastoral / Sermão",
                    descricao_momento=f"Exposição da Palavra sobre o tema: '{tema}'.",
                    conteudo=f"Sermão baseado em {ref_sermon or 'texto designado'}.",
                    metadados={"tema": tema},
                )
            )
            ordem_idx += 1

            # 8. Hinos restantes (Consagração e Louvor Final)
            for i in range(metade, len(scored_hinos)):
                nome_bloco = (
                    NOMES_BLOCOS_LITURGICOS[i]
                    if i < len(NOMES_BLOCOS_LITURGICOS)
                    else f"{i+1}. Momento Especial"
                )
                itens.append(
                    make_hino_item(ordem_idx, nome_bloco, scored_hinos[i])
                )
                ordem_idx += 1

            # 9. Bênção Final
            benc = oracoes["bencao"]
            benc.ordem = ordem_idx
            itens.append(benc)

        # Montagem de blocos legados (para compatibilidade estrita com views e testes existentes)
        for it in itens:
            if it.tipo == TipoItemLiturgico.HINO:
                h = it.conteudo
                scored = it.metadados.get("scored_hino")
                blocos_legados.append(
                    {
                        "bloco": it.titulo_bloco,
                        "hino": h,
                        "score": it.metadados.get("score", 0),
                        "justificativa": it.metadados.get("justificativa", ""),
                        "scored_hino": scored,
                        "item_liturgico": it,
                    }
                )
            else:
                blocos_legados.append(
                    {
                        "bloco": it.titulo_bloco,
                        "tipo": it.tipo.value,
                        "item_liturgico": it,
                        "descricao": it.descricao_momento,
                    }
                )

        plano = PlanoCulto(
            tema=tema,
            template=template,
            itens=itens,
            hinos=hinos_list,
            metadados={
                "ref_abertura": ref_abertura,
                "ref_sermon": ref_sermon,
            },
        )

        return {
            "tema": tema,
            "template": template,
            "hinos": hinos_list,
            "blocos": blocos_legados,
            "itens": itens,
            "plano": plano,
        }

    async def sugerir_playlist_culto(
        self,
        tema_prompt: str,
        num_hinos: int = 6,
        template: str = "geral",
        fonte: str = "atual",
    ) -> dict[str, Any]:
        """
        Analisa a intenção pastoral do usuário e sugere uma ordem litúrgica harmoniosa
        com hinos (Hinário Atual e/ou Antigo), leituras bíblicas e orações contextuais.

        Args:
            tema_prompt: Tema pastoral descrito pelo usuário.
            num_hinos: Quantidade de hinos desejada (4-10).
            template: Template litúrgico ('geral', 'oracao', 'santa_ceia').
            fonte: Hinário fonte ('atual', 'antigo', 'ambos').
        """
        num_hinos = max(4, min(10, num_hinos))

        if not tema_prompt or not tema_prompt.strip():
            return await self._gerar_playlist_padrao(
                num_hinos, template=template, fonte=fonte
            )

        palavras_relevantes = self._extrair_palavras_chave(tema_prompt)
        candidatos_ids = await self._buscar_candidatos_ids(
            palavras_relevantes, num_hinos, fonte=fonte
        )

        # Carrega hinos completos de acordo com a fonte
        hinos_map: dict[tuple[str, int], Hino] = {}
        if fonte in ("atual", "ambos"):
            atuais = await self._get_hinos_completos("atual")
            for hid, h in atuais.items():
                hinos_map[("atual", hid)] = h
        if fonte in ("antigo", "ambos"):
            antigos = await self._get_hinos_completos("antigo")
            for hid, h in antigos.items():
                hinos_map[("antigo", hid)] = h

        temas_por_hino = await self._carregar_temas_candidatos(candidatos_ids)

        candidatos: list[Hino] = [
            hinos_map[chave] for chave in candidatos_ids if chave in hinos_map
        ]

        # Utiliza o HinoRecommender desacoplado para ranking e justificativas
        ranked_scored = self.recommender.rank(
            candidatos=candidatos,
            temas_map=temas_por_hino,
            query=tema_prompt,
            limit=num_hinos,
        )

        return await self._montar_ordem_culto(
            tema=tema_prompt.strip(),
            scored_hinos=ranked_scored,
            template=template,
        )
