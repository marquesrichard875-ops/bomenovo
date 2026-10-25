"""Configuração dos testes: adiciona a pasta web/ ao caminho de importação."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
