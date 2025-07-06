# Configuration file for Hydro Garden MicroPython Controller

MAIN_LOOP_DELAY = 0.01  # seconds

# WiFi Configuration
WIFI_SSID = "riddim_whores"
WIFI_PASSWORD = "nicepassword123"
WIFI_TIMEOUT = 10  # seconds to wait for connection

# UART Configuration for STM Communication
UART_ID = 1
UART_BAUDRATE = 115200
UART_TX_PIN = 21  # GPIO pin for UART TX
UART_RX_PIN = 20  # GPIO pin for UART RX
UART_RESPONSE_TIMEOUT = 0.1  # seconds to wait for STM response
UART_BUFFER_SIZE = 100  # bytes to read from STM

# BLE Configuration
BLE_DEVICE_NAME = "hydro"
BLE_ADVERTISING_INTERVAL = 500000  # microseconds
BLE_RECEIVE_TIMEOUT = 1  # seconds for chunk timeout

# HTTP Server Configuration
USE_HTTP_SERVER = False
HTTP_PORT = 80
HTTP_REQUEST_TIMEOUT = 0.1  # seconds
HTTP_BUFFER_SIZE = 1024  # bytes

# Profile Processing Configuration
PROFILE_CHECK_INTERVAL = 10  # seconds between profile checks
SECONDS_PER_DAY = 86400  # 24 hours in seconds
