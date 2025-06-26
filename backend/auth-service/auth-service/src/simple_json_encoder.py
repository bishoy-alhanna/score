import json
import uuid
from datetime import datetime, date
import decimal

class SimpleJSONEncoder(json.JSONEncoder):
    """
    Custom JSON encoder that extends the default Flask JSON encoder
    to handle UUID, datetime, date, and Decimal objects.
    """
    def default(self, obj):
        if isinstance(obj, uuid.UUID):
            # Convert UUID objects to their string representation
            return str(obj)
        elif isinstance(obj, (datetime, date)):
            # Convert datetime and date objects to ISO 8601 format strings
            return obj.isoformat()
        elif isinstance(obj, decimal.Decimal):
            # Convert Decimal objects to float
            return float(obj)
        # Let the base class default method raise the TypeError for other types
        return super().default(obj)

