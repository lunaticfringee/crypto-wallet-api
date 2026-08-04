import logging
from pythonjsonlogger import jsonlogger
from opentelemetry import trace

class TraceContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        span_context = span.get_span_context()
        record.trace_id = format(span_context.trace_id, "032x") if span_context.trace_id != 0 else None
        record.span_id = format(span_context.span_id, "016x") if span_context.span_id != 0 else None
        return True

logger = logging.getLogger("crypto-wallet-api")
logger.setLevel(logging.INFO)
logger.addFilter(TraceContextFilter())

handler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter("%(asctime)s %(name)s %(levelname)s %(message)s %(trace_id)s %(span_id)s")
handler.setFormatter(formatter)
logger.addHandler(handler)