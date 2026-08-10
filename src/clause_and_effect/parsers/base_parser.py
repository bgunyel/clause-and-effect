"""
Base parser interface for regulation documents
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Any
from pathlib import Path

from docling.datamodel.accelerator_options import AcceleratorDevice, AcceleratorOptions
from docling.datamodel.base_models import ConversionStatus, InputFormat
from docling.datamodel.pipeline_options import RapidOcrOptions, ThreadedPdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling.pipeline.threaded_standard_pdf_pipeline import ThreadedStandardPdfPipeline
from docling_core.types.doc import DoclingDocument


class BaseParser(ABC):
    """Base class for regulation document parsers"""

    def __init__(self, regulation_name: str):
        self.regulation_name = regulation_name

    @abstractmethod
    def parse(self, file_path: Path) -> List[Dict[str, Any]]:
        """
        Parse a regulation document into chunks

        Args:
            file_path: Path to the regulation document

        Returns:
            List of Chunk objects with text and metadata
        """
        pass

    def to_markdown(self, file_path: Path) -> str:
        """
        Convert a source PDF to docling markdown.

        This is the expensive step in the pipeline — roughly six minutes of CPU
        OCR for the GDPR on a machine without a GPU. It is public so the result
        can be exported once and cached on disk, letting the cheap half (the
        article split) re-run in under a second against that export instead of
        repeating the conversion on every parser change.

        Note that the markdown *serializer* loses structure the conversion
        itself captured: nested list items are flattened into one ordered list
        and renumbered, so a sub-item (a) becomes a sibling paragraph. Use
        :meth:`to_dictionary` where within-article hierarchy matters.
        """
        return self._extract_text_from_pdf(file_path)

    def to_dictionary(self, file_path: Path) -> Dict[str, Any]:
        """
        Convert a source PDF to docling's document tree.

        Same conversion as :meth:`to_markdown` — and just as expensive — but
        serialized to the ``DoclingDocument`` dictionary rather than to
        markdown. This keeps what markdown discards: list items retain their
        own ``marker`` and ``enumerated`` flag, so real paragraph numbering
        survives, and every item carries ``prov`` (page number and character
        span) back into the PDF text layer.
        """
        return self._extract_dictionary_from_pdf(file_path)

    @staticmethod
    def _convert_pdf(file_path: Path) -> DoclingDocument:
        """
        Run the docling OCR conversion and return the converted document.

        Both export paths go through here, so markdown and the document tree
        are guaranteed to come from an identically-configured conversion and
        cannot drift apart on pipeline options.
        """
        # document_converter = DocumentConverter()

        pipeline_options = ThreadedPdfPipelineOptions(
            # AUTO resolves to CUDA/MPS where present and CPU otherwise. Pinning
            # CUDA makes docling raise AcceleratorDeviceNotAvailableError on
            # machines without a GPU rather than falling back.
            accelerator_options=AcceleratorOptions(device=AcceleratorDevice.AUTO),
            ocr_options=RapidOcrOptions(backend="openvino"),
            ocr_batch_size=4,
            layout_batch_size=8,
            table_batch_size=4,
        )

        doc_converter = DocumentConverter(
            format_options={
                InputFormat.PDF: PdfFormatOption(
                    pipeline_cls=ThreadedStandardPdfPipeline,
                    pipeline_options=pipeline_options,
                )
            }
        )

        doc_converter.initialize_pipeline(InputFormat.PDF)

        document = doc_converter.convert(file_path)  # TODO: important
        assert document.status == ConversionStatus.SUCCESS
        return document.document

    @classmethod
    def _extract_text_from_pdf(cls, file_path: Path) -> str:
        """Extract all text from PDF, serialized as markdown"""
        return cls._convert_pdf(file_path).export_to_markdown()

    @classmethod
    def _extract_dictionary_from_pdf(cls, file_path: Path) -> Dict[str, Any]:
        """Extract the document tree from PDF, as a plain dictionary"""
        return cls._convert_pdf(file_path).export_to_dict()

    @staticmethod
    def _extract_topics(text: str) -> List[str]:
        """Extract topic keywords from text (simple implementation)"""
        # This is a simplified version - can be enhanced with NLP
        topic_keywords = {
            "consent": ["consent", "agreement", "permission"],
            "deletion": ["deletion", "erasure", "right to be forgotten"],
            "data_subject_rights": ["data subject", "rights", "access"],
            "transfer": ["transfer", "cross-border", "international"],
            "breach": ["breach", "notification", "incident"],
            "processing": ["processing", "lawful basis", "legitimate"],
        }

        topics = []
        text_lower = text.lower()

        for topic, keywords in topic_keywords.items():
            if any(keyword in text_lower for keyword in keywords):
                topics.append(topic)

        return topics or ["general"]
