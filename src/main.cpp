#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <LittleFS.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

constexpr int SCREEN_WIDTH = 128;
constexpr int SCREEN_HEIGHT = 64;

constexpr int OLED_RESET = -1;
constexpr uint8_t OLED_ADDRESS = 0x3C;

Adafruit_SSD1306 display(
    SCREEN_WIDTH,
    SCREEN_HEIGHT,
    &Wire,
    OLED_RESET
);

bool oledAvailable = false;

const char* WIFI_NAME = "GARAGE-ASSIST";
const char* WIFI_PASSWORD = "garage123";

WebServer server(80);

constexpr uint8_t FRONT_TRIGGER_PIN = 4;
constexpr uint8_t FRONT_ECHO_PIN = 5;

constexpr uint8_t SIDE_TRIGGER_PIN = 6;
constexpr uint8_t SIDE_ECHO_PIN = 7;

constexpr uint8_t OLED_SDA_PIN = 8;
constexpr uint8_t OLED_SCL_PIN = 9;

constexpr uint8_t GREEN_LED_PIN = 10;
constexpr uint8_t YELLOW_LED_PIN = 11;
constexpr uint8_t RED_LED_PIN = 12;

constexpr uint8_t BUZZER_PIN = 13;

float frontDistance = -1.0;
float sideDistance = -1.0;

constexpr unsigned long SENSOR_DATA_TIMEOUT_MS =
    1000;

unsigned long lastFrontSuccessTime = 0;
unsigned long lastSideSuccessTime = 0;

constexpr size_t MEASUREMENT_HISTORY_SIZE = 5;

float frontMeasurementHistory[
    MEASUREMENT_HISTORY_SIZE
] = {};

float sideMeasurementHistory[
    MEASUREMENT_HISTORY_SIZE
] = {};

size_t frontMeasurementCount = 0;
size_t sideMeasurementCount = 0;

size_t nextFrontMeasurementIndex = 0;
size_t nextSideMeasurementIndex = 0;

String determineFrontState(float distance)
{
    if (distance < 0.0)
    {
    return "NO_DATA";
    }

    if (distance <= 20.0)
    {
        return "STOP";
    }

    if (distance <= 60.0)
    {
        return "SLOW";
    }

    return "GO";
}


String determineSideState(float distance)
{
    if (distance < 0.0)
    {
    return "NO_DATA";
    }
    if (distance <= 30.0)
    {
        return "BLOCKED";
    }

    return "CLEAR";
}

float measureDistanceCm(
    uint8_t triggerPin,
    uint8_t echoPin
)
{
    digitalWrite(triggerPin, LOW);
    delayMicroseconds(2);

    digitalWrite(triggerPin, HIGH);
    delayMicroseconds(10);

    digitalWrite(triggerPin, LOW);

    unsigned long echoTime =
        pulseIn(
            echoPin,
            HIGH,
            15000UL
        );

    if (echoTime == 0)
    {
        return -1.0;
    }

    return echoTime * 0.0343 / 2.0;
}

void addMeasurement(
    float measurement,
    float history[],
    size_t& measurementCount,
    size_t& nextMeasurementIndex
)
{
    history[nextMeasurementIndex] =
        measurement;

    nextMeasurementIndex =
        (
            nextMeasurementIndex + 1
        )
        % MEASUREMENT_HISTORY_SIZE;

    if (
        measurementCount
        < MEASUREMENT_HISTORY_SIZE
    )
    {
        measurementCount++;
    }
}


float calculateMedian(
    const float history[],
    size_t measurementCount
)
{
    if (measurementCount == 0)
    {
        return -1.0;
    }

    float sortedMeasurements[
        MEASUREMENT_HISTORY_SIZE
    ];

    for (
        size_t index = 0;
        index < measurementCount;
        index++
    )
    {
        sortedMeasurements[index] =
            history[index];
    }

    for (
        size_t firstIndex = 0;
        firstIndex < measurementCount;
        firstIndex++
    )
    {
        for (
            size_t secondIndex =
                firstIndex + 1;
            secondIndex < measurementCount;
            secondIndex++
        )
        {
            if (
                sortedMeasurements[secondIndex]
                < sortedMeasurements[firstIndex]
            )
            {
                float temporaryValue =
                    sortedMeasurements[firstIndex];

                sortedMeasurements[firstIndex] =
                    sortedMeasurements[secondIndex];

                sortedMeasurements[secondIndex] =
                    temporaryValue;
            }
        }
    }

    size_t middleIndex =
        measurementCount / 2;

    if (measurementCount % 2 == 1)
    {
        return sortedMeasurements[
            middleIndex
        ];
    }

    return (
        sortedMeasurements[middleIndex - 1]
        + sortedMeasurements[middleIndex]
    ) / 2.0;
}

void updateTrafficLight()
{
    if (frontDistance < 0.0)
    {
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(YELLOW_LED_PIN, LOW);
    digitalWrite(GREEN_LED_PIN, LOW);
    return;
    }

    bool stopState =
        frontDistance <= 20.0;

    bool slowState =
        frontDistance > 20.0
        && frontDistance <= 60.0;

    bool goState =
        frontDistance > 60.0;

    digitalWrite(
        RED_LED_PIN,
        stopState ? HIGH : LOW
    );

    digitalWrite(
        YELLOW_LED_PIN,
        slowState ? HIGH : LOW
    );

    digitalWrite(
        GREEN_LED_PIN,
        goState ? HIGH : LOW
    );
}

void updateBuzzer()
{
    static unsigned long previousToggleTime = 0;
    static bool buzzerIsOn = false;

    if (frontDistance < 0.0)
    {
    buzzerIsOn = false;
    digitalWrite(BUZZER_PIN, LOW);
    return;
    }

    unsigned long currentTime =
        millis();

    unsigned long toggleInterval;

    if (frontDistance > 60.0)
    {
        buzzerIsOn = false;
        digitalWrite(BUZZER_PIN, LOW);
        return;
    }

    if (frontDistance <= 20.0)
    {
        toggleInterval = 120;
    }
    else
    {
        toggleInterval = 500;
    }

    if (
        currentTime - previousToggleTime
        >= toggleInterval
    )
    {
        previousToggleTime =
            currentTime;

        buzzerIsOn =
            !buzzerIsOn;

        digitalWrite(
            BUZZER_PIN,
            buzzerIsOn ? HIGH : LOW
        );
    }
}

void updateOledDisplay()
{
    if (!oledAvailable)
    {
        return;
    }

    String parkingState =
        determineFrontState(frontDistance);

    String sideState =
        determineSideState(sideDistance);

    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);

    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("GARAGE ASSIST");

    display.setCursor(0, 12);
    display.print("FRONT: ");

    if (frontDistance < 0.0)
    {
        display.println("--");
    }
    else
    {
        display.print(frontDistance, 0);
        display.println(" CM");
    }

    display.setTextSize(2);
    display.setCursor(0, 24);

    if (parkingState == "NO_DATA")
    {
        display.println("NO DATA");
    }
    else
    {
        display.println(parkingState);
    }

    display.setTextSize(1);
    display.setCursor(0, 48);
    display.print("SIDE: ");

    if (sideDistance < 0.0)
    {
        display.println("--");
    }
    else
    {
        display.print(sideDistance, 0);
        display.println(" CM");
    }

    display.setCursor(0, 56);

    if (sideState == "NO_DATA")
    {
        display.println("NO DATA");
    }
    else
    {
        display.println(sideState);
    }

    display.display();
}

void setup()
{
    Serial.begin(115200);

    pinMode(FRONT_TRIGGER_PIN, OUTPUT);
    pinMode(FRONT_ECHO_PIN, INPUT);

    pinMode(SIDE_TRIGGER_PIN, OUTPUT);
    pinMode(SIDE_ECHO_PIN, INPUT);

    pinMode(GREEN_LED_PIN, OUTPUT);
    pinMode(YELLOW_LED_PIN, OUTPUT);
    pinMode(RED_LED_PIN, OUTPUT);

    pinMode(BUZZER_PIN, OUTPUT);

    digitalWrite(FRONT_TRIGGER_PIN, LOW);
    digitalWrite(SIDE_TRIGGER_PIN, LOW);

    digitalWrite(GREEN_LED_PIN, LOW);
    digitalWrite(YELLOW_LED_PIN, LOW);
    digitalWrite(RED_LED_PIN, LOW);

    digitalWrite(BUZZER_PIN, LOW);

    Wire.begin(
    OLED_SDA_PIN,
    OLED_SCL_PIN
);

Wire.beginTransmission(
    OLED_ADDRESS
);

bool oledResponds =
    Wire.endTransmission() == 0;

oledAvailable =
    oledResponds
    && display.begin(
        SSD1306_SWITCHCAPVCC,
        OLED_ADDRESS
    );

if (oledAvailable)
{
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);

    display.println("GARAGE ASSIST");
    display.println("Starting...");

    display.display();
}
else
{
    Serial.println(
        "Hiba: az OLED nem indult el."
    );
}

    if (!LittleFS.begin(true))
    {
        Serial.println("Hiba: a fajlrendszer nem indult el.");
        return;
    }

    WiFi.mode(WIFI_AP);
    WiFi.softAP(WIFI_NAME, WIFI_PASSWORD);

    Serial.println();
    Serial.println("GARAGE-ASSIST elindult.");
    Serial.print("Wi-Fi halozat: ");
    Serial.println(WIFI_NAME);
    Serial.print("Webcim: http://");
    Serial.println(WiFi.softAPIP());

    server.on("/api/status", HTTP_GET, []()
{
    String parkingState =
        determineFrontState(frontDistance);

    String sideState =
        determineSideState(sideDistance);

    String json = "{";

    json += "\"frontDistance\":";
    json += String(frontDistance, 0);
    json += ",";

    json += "\"sideDistance\":";
    json += String(sideDistance, 0);
    json += ",";

    json += "\"parkingState\":\"";
    json += parkingState;
    json += "\",";

    json += "\"sideState\":\"";
    json += sideState;
    json += "\"";

    json += "}";

    server.send(
        200,
        "application/json",
        json
    );
});

    server.on("/", HTTP_GET, []()
{
    if (!LittleFS.exists("/index.html"))
    {
        server.send(
            500,
            "text/plain",
            "Hiba: az index.html nincs feltoltve."
        );

        return;
    }

    File file =
        LittleFS.open(
            "/index.html",
            "r"
        );

    if (!file)
    {
        server.send(
            500,
            "text/plain",
            "Hiba: az index.html nem nyithato meg."
        );

        return;
    }

    server.streamFile(
        file,
        "text/html"
    );

    file.close();
});

    server.serveStatic("/", LittleFS, "/");

    server.begin();
    Serial.println("A webszerver elindult.");
}

void loop()
{
    server.handleClient();
    updateBuzzer();

    static unsigned long previousMeasurementTime = 0;
    static bool measureFrontNext = true;

    unsigned long currentTime =
        millis();

    if (
        currentTime - previousMeasurementTime
        >= 100
    )
    {
        previousMeasurementTime =
            currentTime;

        if (measureFrontNext)
        {
            float measuredFrontDistance =
                measureDistanceCm(
                    FRONT_TRIGGER_PIN,
                    FRONT_ECHO_PIN
                );

            if (measuredFrontDistance > 0)
            {
                addMeasurement(
                    measuredFrontDistance,
                    frontMeasurementHistory,
                    frontMeasurementCount,
                    nextFrontMeasurementIndex
                );

                frontDistance =
                    calculateMedian(
                        frontMeasurementHistory,
                        frontMeasurementCount
                    );

                lastFrontSuccessTime =
                    millis();
            }
            else if (
                millis() - lastFrontSuccessTime
                >= SENSOR_DATA_TIMEOUT_MS
            )
            {
                frontDistance = -1.0;
                frontMeasurementCount = 0;
                nextFrontMeasurementIndex = 0;
            }
        }
        else
        {
            float measuredSideDistance =
                measureDistanceCm(
                    SIDE_TRIGGER_PIN,
                    SIDE_ECHO_PIN
                );

            if (measuredSideDistance > 0)
{
    addMeasurement(
        measuredSideDistance,
        sideMeasurementHistory,
        sideMeasurementCount,
        nextSideMeasurementIndex
    );

    sideDistance =
        calculateMedian(
            sideMeasurementHistory,
            sideMeasurementCount
        );

    lastSideSuccessTime =
        millis();
}
else if (
    millis() - lastSideSuccessTime
    >= SENSOR_DATA_TIMEOUT_MS
)
{
    sideDistance = -1.0;
    sideMeasurementCount = 0;
    nextSideMeasurementIndex = 0;
}
        }

        measureFrontNext =
            !measureFrontNext;

        updateTrafficLight();
        updateOledDisplay();
    }
    updateBuzzer();
}