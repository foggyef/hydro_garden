import os
import ujson

from util import Channel, Profile, parse_profile_from_dict, PointsProfile, FunctionProfile

def save_var(key: str, value: any):
    filename = f"{key}.json"
    with open(filename, "w") as f:
        ujson.dump(value, f)
    print(f"Saved {key} to {filename}")

def load_var(key: str, default: any = None, parse_type: type | None = None) -> any:
    # check if file exists
    filename = f"{key}.json"
    try:
        os.stat(filename)
    except OSError:
        print(f"File {key}.json does not exist")
        return default
    try:
        with open(filename, "r") as f:
            value = ujson.load(f)
            if parse_type is not None:
                return parse_type(value)
            return value
    except Exception as e:
        print(f"Error loading {key}: {e}")
        return default
    
def save_profile(profile: dict[Channel, Profile]):
    # profile_type = type(profile.values()[0])
    profile_type = "FunctionProfile"  # TODO make this dynamic
    profile_raw = {}
    for channel, profile in profile.items():
        profile_raw[str(channel)] = profile.to_raw()
    
    save_var("profile", profile_raw)

def load_profile() -> dict[Channel, Profile]:
    profile_raw = load_var("profile", default = {})
    if not profile_raw:
        return {}
    return parse_profile_from_dict(profile_raw, FunctionProfile)