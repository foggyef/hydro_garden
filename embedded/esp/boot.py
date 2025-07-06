import network
from machine import UART, Pin
import socket
import bluetooth
import ujson
import time

from util import Channel, PointsProfile, Command, Profile, FunctionProfile, parse_profile
from ble_simple_peripheral import BLESimplePeripheral
from storage import save_var, load_var, save_profile, load_profile
from config import *

### globals ###

# Load persistent data on startup
run_profile = load_var("run_profile_bool", default = False, parse_type = bool)
profile = load_profile()
grow_light_color = load_var("grow_light_color", default = [225,225,225])

uart1 = UART(UART_ID, baudrate=UART_BAUDRATE, tx=Pin(UART_TX_PIN), rx=Pin(UART_RX_PIN))

http_server = None

ble = bluetooth.BLE()
ble_peripheral = BLESimplePeripheral(ble, name=BLE_DEVICE_NAME)

recv_timeout = BLE_RECEIVE_TIMEOUT
recv_chunks = []
t_last_chunk = None

### end globals ###


def process_command_str(command_str: str) -> None:
    global profile, run_profile

    print("Processing command:", command_str)
    command = Command(command_str.split(":", 1)[0])
    if command == Command.START:
        run_profile = True
        save_var("run_profile_bool", run_profile)
    elif command == Command.STOP:
        run_profile = False
        save_var("run_profile_bool", run_profile)
    elif command == Command.POINTS_PROFILE:
        # update profile
        profile_str = command_str.split(":", 1)[1]
        profile = parse_profile(profile_str, PointsProfile)
        save_profile(profile)
    elif command == Command.FUNC_PROFILE:
        # update profile
        profile_str = command_str.split(":", 1)[1]
        profile = parse_profile(profile_str, FunctionProfile)
        save_profile(profile)
    elif command == Command.GROW_LIGHT_COLOR:
        grow_light_color = list(map(int, command_str.split(":", 1)[1].split(",")))
        save_var("grow_light_color", grow_light_color)


# Process received BLE data
def on_rx(v):
    global recv_chunks, t_last_chunk

    print("BLE received:", v)
    if t_last_chunk is None:
        t_last_chunk = time.time()
    deadline = t_last_chunk + recv_timeout
    if time.time() > deadline:
        print("Previous chunk train timed out. Starting new chunk train.")
        recv_chunks.clear()
    t_last_chunk = time.time()

    recv_chunks.append(v)

    if b"\n" in v:
        # we received the last chunk
        recv_chunks[-1] = recv_chunks[-1].replace(b"\n", b"")
        recv_message = b"".join(recv_chunks).decode("utf-8")
        recv_chunks = []
        t_last_chunk = None
        try:
            process_command_str(recv_message)
        except Exception as e:
            print("Error processing BLE command:", e)
            ble_peripheral.send(f"Error: {str(e)}\n".encode("utf-8"))


# Transmit command to STM via UART
def transmit_to_stm(channel: Channel, value: float):
    global uart1

    command_dict = {"channel": str(channel), "value": f"{value}"}

    if channel.value == Channel.LIGHT:
        intensity_factor = float(command_dict["value"])
        color_intensity = tuple(int(c*intensity_factor) for c in grow_light_color)
        command_dict["value"] = f"{color_intensity[0]},{color_intensity[1]},{color_intensity[2]}"

    command = ujson.dumps(command_dict).encode("utf-8") + b"\n"
    
    # Clear any existing data in the buffer before sending
    uart1.read()  # Clear receive buffer
    
    uart1.write(command)
    print("Transmitted to STM:", command)
    
    time.sleep(UART_RESPONSE_TIMEOUT)  # Allow time for response
    response = uart1.read(UART_BUFFER_SIZE)
    print("Received from STM:", response)


def process_profile() -> None:
    global profile

    print("Processing profile", profile)
    t_since_start_of_day = time.time() % SECONDS_PER_DAY
    for channel, channel_profile in profile.items():
        value = channel_profile.calc_y(t_since_start_of_day)
        print(f"Channel {channel} value: {value}")
        if channel.value == Channel.HUMIDIFIER:
            continue  # TODO: include humidifier once added to the PCB
        transmit_to_stm(channel, value)


def start_http_server() -> None:
    global http_server
    
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(WIFI_SSID, WIFI_PASSWORD)

    while not wlan.isconnected():
        time.sleep(1)
    print("Connected to WiFi:", wlan.ifconfig()[0])

    # HTTP server setup
    addr = socket.getaddrinfo('0.0.0.0', HTTP_PORT)[0][-1]
    http_server = socket.socket()
    http_server.bind(addr)
    http_server.listen(1)
    http_server.setblocking(False)  # Non-blocking socket
    print("Listening on", addr)


def handle_http_requests() -> None:
    global http_server  
    try:
        cl, addr = http_server.accept()
        cl.settimeout(HTTP_REQUEST_TIMEOUT)
        request = cl.recv(HTTP_BUFFER_SIZE).decode("utf-8")
        if 'POST /command' in request:
            body_start = request.find('\r\n\r\n') + 4
            if body_start > 3:
                payload = request[body_start:]
                try:
                    command_str = payload.decode("utf-8") if isinstance(payload, bytes) else payload
                    process_command_str(command_str)
                    response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK"
                except Exception as e:
                    response = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nError: " + str(e)
            else:
                response = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nNo payload"
        else:
            response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nNot Found"
        cl.send(response.encode("utf-8"))
        cl.close()
    except OSError as e:
        if e.args[0] == 11:  # EAGAIN, no connection pending
            pass
        else:
            print("Socket error:", e)


if USE_HTTP_SERVER:
    start_http_server()

ble_peripheral.on_write(on_rx)

# Main loop
last_profile_check = 0
while True:
    # process profile every 10 seconds
    current_time = time.time()
    if current_time - last_profile_check >= PROFILE_CHECK_INTERVAL:
        if run_profile:
            process_profile()
            last_profile_check = current_time
    
    if USE_HTTP_SERVER:
        handle_http_requests()
    
    # Small delay to prevent tight looping
    time.sleep(MAIN_LOOP_DELAY)



