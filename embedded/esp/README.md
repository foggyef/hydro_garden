# HTTP API

## POST /command

Send commands in the same format as BLE:

### Start a profile

```
POST /command
Content-Type: text/plain

START
```

### Stop all profiles

```
POST /command
Content-Type: text/plain

STOP
```

# ESP to STM communication

### Light control

value is a comma separated list of RGB values

```json
{
    "channel": "light",
    "value": "0,0,0"
}
```

### Aerator control

value is a boolean

```json
{
    "channel": "aerator",
    "value": "1"
}
```

### Fan control

value is a boolean

```json
{
    "channel": "fan_out",
    "value": "1"
}
```

```json
{
    "channel": "fan_in",
    "value": "1"
}
```