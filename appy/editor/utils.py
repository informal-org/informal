import shortuuid

def encode_uuid(full_uuid):
    return shortuuid.encode(full_uuid)

def decode_uuid(short_uuid):
    return shortuuid.decode(short_uuid)
