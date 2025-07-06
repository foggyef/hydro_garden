import math
import ujson

from config import SECONDS_PER_DAY

class InvalidProfileError(Exception):
    pass


class Command(str):
    START = "START"
    STOP = "STOP"
    FUNC_PROFILE = "FUNC_PROFILE"
    POINTS_PROFILE = "POINTS_PROFILE"
    GROW_LIGHT_COLOR = "GROW_LIGHT_COLOR"
    
    def __init__(self, str: str):
        if str == self.START:
            self.value = self.START
        elif str == self.STOP:
            self.value = self.STOP
        elif str == self.FUNC_PROFILE:
            self.value = self.FUNC_PROFILE
        elif str == self.POINTS_PROFILE:
            self.value = self.POINTS_PROFILE
        elif str == self.GROW_LIGHT_COLOR:
            self.value = self.GROW_LIGHT_COLOR
        else:
            raise ValueError(f"Invalid command: {str}")
        
    def __str__(self):
        return self.value
        

class Channel:
    LIGHT = "light"
    AERATOR = "aerator"
    FAN_OUT = "fan_out"
    FAN_IN = "fan_in"
    HUMIDIFIER = "humidifier"

    def __init__(self, str: str):
        str = str.lower()
        if str == self.LIGHT:
            self.value = self.LIGHT
        elif str in [self.AERATOR, "bubbler"]:
            self.value = self.AERATOR
        elif str in [self.FAN_OUT, "fan out"]:
            self.value = self.FAN_OUT
        elif str in [self.FAN_IN, "fan in"]:
            self.value = self.FAN_IN
        elif str == self.HUMIDIFIER:
            self.value = self.HUMIDIFIER
        else:
            raise ValueError(f"Invalid channel: {str}")
        
    def __str__(self):
        return self.value


class Profile:
    # @abstractmethod
    def calc_y(self, t: float) -> float:
        pass

    # @abstractmethod
    def from_raw(cls, raw: any) -> "Profile":
        pass

    # @abstractmethod
    def to_raw(self) -> any:
        pass


class PointsProfile(Profile):
    def __init__(self, time_points: list[float], value_points: list[float]):
        self.time_points = time_points
        self.value_points = value_points

    @classmethod
    def from_raw(cls, points: list[tuple[float | str, float | str]]) -> "PointsProfile":
        # sort by time
        cls.validate_points(points)
        points.sort(key=lambda x: x[0])
        time_points = [float(point[0]) for point in points]
        value_points = [float(point[1]) for point in points]
        return cls(time_points, value_points)
    
    def to_raw(self) -> list[tuple[float, float]]:
        return [(t, v) for t, v in zip(self.time_points, self.value_points)]

    def calc_y(self, t: float) -> float:
        index = find_closest_index(self.time_points, t)
        if index is None:
            return 0.0  # Default value for empty profile
        return self.value_points[index]
    
    @staticmethod
    def validate_points(points: list[tuple[float, float]]) -> None:
        for point in points:
            if not isinstance(point, tuple) or len(point) != 2:
                raise InvalidProfileError(f"Profile item {point} is not a tuple of length 2")
            if not isinstance(point[0], float) or not isinstance(point[1], float):
                raise InvalidProfileError(f"Profile item {point} is not a tuple of floats")
            if point[0] < 0 or point[1] < 0:
                raise InvalidProfileError(f"Profile item {point} is not a tuple of non-negative floats")
    

class FunctionProfile(Profile):
    def __init__(self, a: float, b: float, c: float, k: float, n: int):
        self.a = a
        self.b = b
        self.c = c
        self.k = k
        self.n = n

    @classmethod
    def from_raw(cls, profile: dict[str, str]) -> "FunctionProfile":
        a = float(profile["a"])
        b = float(profile["b"])
        c = float(profile["c"])
        k = float(profile["k"])
        n = int(profile["n"])
        return cls(a, b, c, k, n)
    
    def to_raw(self) -> dict[str, str]:
        return {
            "a": str(self.a),
            "b": str(self.b),
            "c": str(self.c),
            "k": str(self.k),
            "n": str(self.n)
        }
        
    def calc_y(self, t: float) -> float:
        x = (t / SECONDS_PER_DAY) * 24 - 12 # Map to -12 to 12 hours
        f = self.n / 48.0 # Frequency: n peaks over 24 hours
        theta = 2 * math.pi * f * (x - self.c)
        term = math.sin(theta) / self.b
        yRaw = self.a * 100 * math.exp(-math.pow(abs(term), self.k))
        y = max(yRaw, 0)
        y_normalized = y / 100.0
        return y_normalized


def parse_profile(profile_str: str, profile_cls: type[Profile]) -> dict[Channel, Profile]:
    profile = {}
    raw_profile = ujson.loads(profile_str)
    return parse_profile_from_dict(raw_profile, profile_cls)

def parse_profile_from_dict(profile_dict: dict, profile_cls: type[Profile]) -> dict[Channel, Profile]:
    profile = {}
    for key, value in profile_dict.items():
        profile[Channel(key)] = profile_cls.from_raw(value)
    return profile


def find_closest_index(sorted_list, x):
    if not sorted_list:  # Handle empty list
        return None
    
    # Binary search to find insertion point
    left, right = 0, len(sorted_list)
    while left < right:
        mid = (left + right) // 2
        if sorted_list[mid] < x:
            left = mid + 1
        else:
            right = mid
    
    pos = left
    
    # Handle edge cases
    if pos == 0:
        return 0
    if pos == len(sorted_list):
        return len(sorted_list) - 1
    
    # Compare the element at pos and pos-1
    before = sorted_list[pos - 1]
    after = sorted_list[pos]
    
    # Return the one with the smallest absolute difference
    return pos - 1 if abs(before - x) <= abs(after - x) else pos
