"""
{ Clause & Effect }
Where Regulations Meet AI Reasoning

An enterprise-grade AI compliance assistant built with agentic RAG.
"""

__version__ = "0.1.0"
__author__ = "Bertan Günyel"

from .retrieval import *
from .parsers import *

__all__ = [
    "EmbeddingGenerator",
    "GDPRParser",
    "VectorDatabase",
]