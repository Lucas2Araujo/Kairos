"""
Testes unitários para o MindMapStudio e utilitário storage_manager.
"""

from pathlib import Path
from unittest.mock import patch

from src.components.mind_map_studio import MindMapStudio, _project_root
from src.utils.storage_manager import _resolve_config_dir


def test_mind_map_studio_project_root():
    """Valida que _project_root aponta para a raiz do Hinário_App."""
    assert _project_root.name == "Hinário_App"
    assert (_project_root / "src").exists()


def test_mind_map_studio_node_id_no_collision_after_deletion():
    """Garante que a deleção de nós intermediários não causa colisão de IDs."""
    studio = MindMapStudio(root_word="Fé")
    assert studio._next_node_id == 1

    # Adiciona nó 1
    studio.input_field.value = "Ideia 1"
    studio._add_node_from_input()
    assert studio.nodes[0]["id"] == "node_1"

    # Adiciona nó 2
    studio.input_field.value = "Ideia 2"
    studio._add_node_from_input()
    assert studio.nodes[1]["id"] == "node_2"

    # Remove o primeiro nó (índice 0)
    studio._remove_node(0)
    assert len(studio.nodes) == 1
    assert studio.nodes[0]["id"] == "node_2"

    # Adiciona um novo nó - não deve colidir com node_2
    studio.input_field.value = "Ideia 3"
    studio._add_node_from_input()
    assert len(studio.nodes) == 2
    assert studio.nodes[1]["id"] == "node_3"


def test_mind_map_studio_initial_nodes_max_id():
    """Garante que nós iniciais determinam corretamente o próximo ID."""
    initial = [
        {"id": "node_5", "text": "Existente 5"},
        {"id": "node_2", "text": "Existente 2"},
    ]
    studio = MindMapStudio(root_word="Esperança", initial_nodes=initial)
    assert studio._next_node_id == 6

    studio.input_field.value = "Nova Ideia"
    studio._add_node_from_input()
    assert studio.nodes[-1]["id"] == "node_6"


def test_storage_manager_resolve_config_dir(tmp_path):
    """Valida que _resolve_config_dir utiliza DatabaseConnection._get_user_data_dir()."""
    mock_dir = tmp_path / "custom_user_dir"
    with patch("src.database.connection.DatabaseConnection._get_user_data_dir", return_value=mock_dir):
        resolved = _resolve_config_dir()
        assert resolved == mock_dir
