"""
Módulo de modelos de dados do Kairós.
Exporta modelos canônicos em Português e aliases em Inglês para retrocompatibilidade total.
"""

from .biblia import PassagemBiblica, Versiculo
from .commentary import CommentaryAuthor, CommentaryItem
from .comparativo import BlocoDiff, EstatisticasDiff, HinoComparativo
from .cross_reference import CrossReferenceItem
from .culto import ItemLiturgico, PlanoCulto, TipoItemLiturgico
from .devotional import Devotional
from .escola_sabatina import SSDay, SSLesson, SSQuarterly, SSUserNote
from .hino import Hino
from .pericope import Pericope
from .quiz import QuizQuestion, QuizQuestionInternal

# Aliases em Português / Inglês
AutorComentario = CommentaryAuthor
ItemComentario = CommentaryItem
ItemReferenciaCruzada = CrossReferenceItem
Meditacao = Devotional
DiaLicao = SSDay
Licao = SSLesson
Trimestre = SSQuarterly
NotaUsuario = SSUserNote
PerguntaQuiz = QuizQuestion
PerguntaQuizInterna = QuizQuestionInternal

__all__ = [
    # Modelos canônicos / existentes
    "BlocoDiff",
    "EstatisticasDiff",
    "Hino",
    "HinoComparativo",
    "Versiculo",
    "PassagemBiblica",
    "CommentaryAuthor",
    "CommentaryItem",
    "CrossReferenceItem",
    "ItemLiturgico",
    "PlanoCulto",
    "TipoItemLiturgico",
    "Devotional",
    "SSQuarterly",
    "SSLesson",
    "SSDay",
    "SSUserNote",
    "Pericope",
    "QuizQuestion",
    "QuizQuestionInternal",
    # Aliases em Português
    "AutorComentario",
    "ItemComentario",
    "ItemReferenciaCruzada",
    "Meditacao",
    "DiaLicao",
    "Licao",
    "Trimestre",
    "NotaUsuario",
    "PerguntaQuiz",
    "PerguntaQuizInterna",
]
