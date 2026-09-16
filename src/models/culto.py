from dataclasses import dataclass, field
from enum import Enum
from typing import Any

from src.models.hino import Hino


class TipoItemLiturgico(str, Enum):
    """Tipos de momentos litúrgicos de uma ordem de culto."""

    HINO = "hino"
    LEITURA_BIBLICA = "leitura_biblica"
    ORACAO = "oracao"
    PREGACAO = "pregacao"
    MOMENTO_CIVIL = "momento_civil"


@dataclass
class ItemLiturgico:
    """
    Modelo polimórfico de item da ordem de culto.
    Desacopla o bloco litúrgico da obrigatoriedade de ser exclusivamente um Hino,
    permitindo representação rica de Leituras Bíblicas, Orações, Sermões e avisos.
    """

    ordem: int
    tipo: TipoItemLiturgico
    titulo_bloco: str
    descricao_momento: str
    conteudo: Any
    metadados: dict[str, Any] = field(default_factory=dict)


@dataclass
class PlanoCulto:
    """
    Ordem de culto litúrgico completa, estruturada e determinística.
    """

    tema: str
    template: str
    itens: list[ItemLiturgico] = field(default_factory=list)
    hinos: list[Hino] = field(default_factory=list)
    metadados: dict[str, Any] = field(default_factory=dict)

