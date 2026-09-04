"""
The capture half of the call log: what turns a model call into rows.

``src/db/`` below this point is storage — engines, tables, repositories. This
package is the other half: the context a call runs in, the metadata read off the
response, and the recorder that writes the row.

**This ``__init__`` deliberately exports nothing.** Importing a name from a
package runs its ``__init__``, and :mod:`src.db.capture.recorder` reaches
``src.db.repos`` and therefore SQLAlchemy — measured at 0.495s.
:mod:`src.llm.call` imports :mod:`src.db.capture.response` for the
response-metadata readers, and that module costs nothing to import; re-exporting
the recorder here would put half a second on every importer of a stage module,
which is the exact cost that tier is arranged to avoid. Import the submodule you
need.
"""