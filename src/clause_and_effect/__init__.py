"""
{ Clause & Effect }
Where Regulations Meet AI Reasoning

An enterprise-grade AI compliance assistant built with agentic RAG.
"""

__version__ = "0.1.0"
__author__ = "Bertan Günyel"

import logging

# The library convention: a logger that goes nowhere unless the application
# configures one. Without this, a module logging a warning while no handler is
# installed makes Python emit "No handlers could be found" — and adding a real
# handler here would let the library override the choices of whatever program
# imported it. Scripts call `src.logging_setup.setup_logging()`; nothing under
# this package configures logging or writes to stdout.
logging.getLogger(__name__).addHandler(logging.NullHandler())
