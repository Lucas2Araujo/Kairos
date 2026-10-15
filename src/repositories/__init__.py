"""
Módulo de repositórios do Kairós.
Exporta repositórios canônicos e aliases em Português/Inglês para retrocompatibilidade total.
"""

from .biblia_repository import BibliaRepository
from .commentary_repository import CommentaryRepository
from .comparativo_repository import ComparativoRepository
from .cross_reference_repository import CrossReferenceRepository
from .culto_repository import CultoRepository
from .escola_sabatina_repository import EscolaSabatinaRepository
from .favorito_repository import FavoritoRepository
from .hino_repository import HinoRepository
from .historico_repository import HistoricoRepository
from .meditacao_repository import DevotionalRepository, MeditacaoRepository
from .pericope_repository import PericopeRepository

# Aliases em Português
ComentarioRepository = CommentaryRepository
ReferenciaCruzadaRepository = CrossReferenceRepository

__all__ = [
    # Repositórios canônicos / existentes
    "BibliaRepository",
    "CommentaryRepository",
    "ComentarioRepository",
    "ComparativoRepository",
    "CrossReferenceRepository",
    "ReferenciaCruzadaRepository",
    "CultoRepository",
    "EscolaSabatinaRepository",
    "FavoritoRepository",
    "HinoRepository",
    "HistoricoRepository",
    "DevotionalRepository",
    "MeditacaoRepository",
    "PericopeRepository",
]
