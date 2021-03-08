import shortuuid

def encode_uuid(full_uuid):
    return shortuuid.encode(full_uuid)

def decode_uuid(short_uuid):
    return shortuuid.decode(short_uuid)

class Sync:
    # Figures out which ones are existing, which ones are new and which ones are stale
    def __init__(self, current, target):
        # Current = list of current IDs
        # Target = target list we want to end up with
        current_set = set(current)
        target_set = set(target)

        # Exists in both current and target. Can be ignored
        self.existing = target_set.intersection(current_set)
        # Stale = exists in the current set, but no longer included in target set
        self.remove = current_set - target_set
        # Create = exists in the target set, but not present in the current set yet
        self.create = target_set - current_set
