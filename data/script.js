const dashboardStates = {
    go: {
        status: "GO",
        frontDistance: 118,
        stateColor: "#35e2a3",
        needleAngle: "-42deg",
        sideStatus: "CLEAR",
        sideDistance: 86,
        sideColor: "#35e2a3"
    },

    slow: {
        status: "SLOW",
        frontDistance: 42,
        stateColor: "#ffc24c",
        needleAngle: "18deg",
        sideStatus: "CLEAR",
        sideDistance: 86,
        sideColor: "#35e2a3"
    },

    stop: {
        status: "STOP",
        frontDistance: 18,
        stateColor: "#ff5365",
        needleAngle: "67deg",
        sideStatus: "CLEAR",
        sideDistance: 86,
        sideColor: "#35e2a3"
    },

    blocked: {
        status: "GO",
        frontDistance: 67,
        stateColor: "#35e2a3",
        needleAngle: "-2deg",
        sideStatus: "BLOCKED",
        sideDistance: 16,
        sideColor: "#ff5365"
    },

    no_data: {
    status: "NO DATA",
    frontDistance: "--",
    stateColor: "#7f8b95",
    needleAngle: "-42deg",
    sideStatus: "NO DATA",
    sideDistance: "--",
    sideColor: "#7f8b95"
}
};

const parkingStatus =
    document.getElementById("parking-status");

const mainDistanceValue =
    document.getElementById("main-distance-value");

const frontDistanceValue =
    document.getElementById("front-distance-value");

const sideStatus =
    document.getElementById("side-status");

const sideDistanceValue =
    document.getElementById("side-distance-value");

const sideZoneLabel =
    document.getElementById("side-zone-label");

const demoButtons =
    document.querySelectorAll("[data-state]");

const isLocalDemo =
    window.location.hostname === "127.0.0.1"
    || window.location.hostname === "localhost"
    || window.location.protocol === "file:";    

const connectionStatus =
    document.getElementById(
        "connection-status"
    );

const connectionState =
    document.getElementById(
        "connection-state"
    );

const connectionDetail =
    document.getElementById(
        "connection-detail"
    );


function showConnectionStatus(statusName) {
    if (
        !connectionStatus
        || !connectionState
        || !connectionDetail
    ) {
        return;
    }

    const statusSettings = {
        demo: {
            state: "DEMO",
            detail: "· LOCAL"
        },

        connecting: {
            state: "CONNECTING",
            detail: "· PLEASE WAIT"
        },

        online: {
            state: "LIVE",
            detail: "· 0.2s"
        },

        offline: {
            state: "OFFLINE",
            detail: "· RETRYING"
        }
    };

    const selectedStatus =
        statusSettings[statusName];

    if (!selectedStatus) {
        return;
    }

    connectionStatus.classList.remove(
        "demo",
        "connecting",
        "online",
        "offline"
    );

    connectionStatus.classList.add(
        statusName
    );

    connectionState.textContent =
        selectedStatus.state;

    connectionDetail.textContent =
        selectedStatus.detail;
}    

function showDashboardState(stateName) {
    const selectedState =
        dashboardStates[stateName];

    if (!selectedState) {
        return;
    }

    document.documentElement.style.setProperty(
        "--state-color",
        selectedState.stateColor
    );

    document.documentElement.style.setProperty(
        "--side-color",
        selectedState.sideColor
    );

    document.documentElement.style.setProperty(
        "--needle-angle",
        selectedState.needleAngle
    );

    parkingStatus.textContent =
        selectedState.status;

    mainDistanceValue.textContent =
        selectedState.frontDistance;

    frontDistanceValue.textContent =
        selectedState.frontDistance;

    sideStatus.textContent =
        selectedState.sideStatus;

    sideDistanceValue.textContent =
        `${selectedState.sideDistance} CM`;

    sideZoneLabel.textContent =
        selectedState.sideStatus;

    demoButtons.forEach((button) => {
        const isActive =
            button.dataset.state === stateName;

        button.classList.toggle(
            "active",
            isActive
        );
    });
}

demoButtons.forEach((button) => {
    if (!isLocalDemo) {
        button.hidden = true;
        button.disabled = true;
        return;
    }

    button.addEventListener("click", () => {
        showDashboardState(
            button.dataset.state
        );
    });
});

async function updateDashboardFromDevice() {
    
    const controller =
    new AbortController();

    const timeoutId =
        setTimeout(
            () => controller.abort(),
            2500
        );

    try {
        const response = await fetch(
            "/api/status",
            { 
                cache: "no-store",
                signal: controller.signal
            }
        );

        if (!response.ok) {
            showDashboardState("no_data");
            showConnectionStatus("offline");
            return false;
        }

        const data = await response.json();

        const frontHasData =
            Number.isFinite(data.frontDistance)
            && data.frontDistance >= 0;

        const sideHasData =
            Number.isFinite(data.sideDistance)
            && data.sideDistance >= 0;

        const frontStateName =
            frontHasData
                ? data.parkingState.toLowerCase()
                : "no_data";

        const sideIsBlocked =
            sideHasData
            && data.sideState === "BLOCKED";

        const currentSideColor =
            !sideHasData
                ? "#7f8b95"
                : sideIsBlocked
                    ? "#ff5365"
                    : "#35e2a3";

        showDashboardState(frontStateName);

        document.documentElement.style.setProperty(
            "--side-color",
            currentSideColor
        );

        const frontDisplayValue =
            frontHasData
                ? data.frontDistance
                : "--";

        const sideDisplayValue =
            sideHasData
                ? `${data.sideDistance} CM`
                : "--";

        const sideDisplayState =
            sideHasData
                ? data.sideState
                : "NO DATA";

        mainDistanceValue.textContent =
            frontDisplayValue;

        frontDistanceValue.textContent =
            frontDisplayValue;

        sideStatus.textContent =
            sideDisplayState;

        sideDistanceValue.textContent =
            sideDisplayValue;

        sideZoneLabel.textContent =
            sideDisplayState;

        const blockedButton =
            document.querySelector(
                '[data-state="blocked"]'
            );

        if (blockedButton) {
            blockedButton.classList.toggle(
                "active",
                sideIsBlocked
            );
        }
        showConnectionStatus("online");
        return true;
    }
    catch {
        showDashboardState("no_data");
        showConnectionStatus("offline");
        return false;
    }
    finally {
    clearTimeout(timeoutId);
    }
}

function startLiveUpdates() {
    
    if (isLocalDemo) {
        showConnectionStatus("demo");
        return;
    }

    showConnectionStatus("connecting");

    async function requestNextUpdate() {
        const updateWasSuccessful =
            await updateDashboardFromDevice();

        const nextUpdateDelay =
            updateWasSuccessful
                ? 200
                : 1000;

        setTimeout(
            requestNextUpdate,
            nextUpdateDelay
        );
    }

    requestNextUpdate();
}

showDashboardState("slow");
startLiveUpdates();
