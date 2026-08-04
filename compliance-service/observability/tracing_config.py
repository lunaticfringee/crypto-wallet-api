from dotenv import load_dotenv
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

load_dotenv()
SERVICE_NAME = os.getenv("SERVICE_NAME", "unknown-service")

def setup_tracing(app):
    resource = Resource.create({"service.name": SERVICE_NAME})
    trace.set_tracer_provider(TracerProvider(resource=resource))
    tracer_provider = trace.get_tracer_provider()

    otlp_exporter = OTLPSpanExporter(endpoint="http://jaeger:4318/v1/traces")
    span_processor = BatchSpanProcessor(otlp_exporter)
    tracer_provider.add_span_processor(span_processor)

    RequestsInstrumentor().instrument()
    FastAPIInstrumentor.instrument_app(app)