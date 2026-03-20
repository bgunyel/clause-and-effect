"""
Base parser interface for regulation documents
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Dict, Any
from pathlib import Path

from docling.datamodel.accelerator_options import AcceleratorDevice, AcceleratorOptions
from docling.datamodel.base_models import ConversionStatus, InputFormat
from docling.datamodel.pipeline_options import RapidOcrOptions, ThreadedPdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption
from docling.pipeline.threaded_standard_pdf_pipeline import ThreadedStandardPdfPipeline


@dataclass
class Chunk:
    """A chunk of text from a regulation document"""
    id: str
    text: str
    metadata: Dict[str, Any]

    def __repr__(self):
        return f"Chunk(id='{self.id}', metadata={self.metadata})"


class BaseParser(ABC):
    """Base class for regulation document parsers"""

    def __init__(self, regulation_name: str):
        self.regulation_name = regulation_name

    @abstractmethod
    def parse(self, file_path: Path) -> List[Chunk]:
        """
        Parse a regulation document into chunks

        Args:
            file_path: Path to the regulation document

        Returns:
            List of Chunk objects with text and metadata
        """
        pass

    @staticmethod
    def _extract_text_from_pdf(file_path: Path) -> str:
        """Extract all text from PDF"""
        # document_converter = DocumentConverter()

        pipeline_options = ThreadedPdfPipelineOptions(
            accelerator_options=AcceleratorOptions(device=AcceleratorDevice.CUDA),
            ocr_options=RapidOcrOptions(backend="openvino"),
            ocr_batch_size=4,
            layout_batch_size=64,
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
        text = document.document.export_to_markdown()
        return text

    def _create_chunk_id(self, article_num: str, paragraph: str | None = None) -> str:
        """Generate a unique chunk ID"""
        base_id = f"{self.regulation_name.lower()}_article_{article_num}"
        if paragraph:
            return f"{base_id}_para_{paragraph}"
        return base_id

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
