// Monster Weather: temperature and sky on the taskbar; click for now, next 12 hours and 7 days.
// Data: Open-Meteo (free, no account). Your town is found from your internet address unless you pick one.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    property var now: null        // {temp, feels, hum, wind, code, day}
    property var hours: []        // [{t, temp, code, day}]
    property var days: []         // [{d, max, min, code, rain}]
    property string place: Plasmoid.configuration.place
    property string status: "Loading the weather…"
    property bool searching: false
    property var results: []
    readonly property bool f: Plasmoid.configuration.fahrenheit
    readonly property string unit: f ? "°F" : "°C"

    Plasmoid.icon: now ? iconFor(now.code, now.day) : "weather-few-clouds"
    toolTipMainText: now ? Math.round(now.temp) + unit + " · " + textFor(now.code) : "Monster Weather"
    toolTipSubText: place ? place + (days.length ? " · today " + Math.round(days[0].max) + "° / " + Math.round(days[0].min) + "°" : "") : status

    // ---------- weather codes (WMO) ----------
    function textFor(c) {
        if (c === 0) return "Clear"; if (c <= 2) return "Partly cloudy"; if (c === 3) return "Cloudy"
        if (c === 45 || c === 48) return "Fog"; if (c >= 51 && c <= 57) return "Drizzle"
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return c >= 65 && c <= 67 || c === 82 ? "Heavy rain" : "Rain"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "Snow"; if (c >= 95) return "Thunderstorm"
        return "—"
    }
    function iconFor(c, day) {
        if (c === 0) return day ? "weather-clear" : "weather-clear-night"
        if (c <= 2) return day ? "weather-few-clouds" : "weather-few-clouds-night"
        if (c === 3) return "weather-overcast"
        if (c === 45 || c === 48) return "weather-fog"
        if (c >= 51 && c <= 57) return day ? "weather-showers-scattered" : "weather-showers-scattered-night"
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "weather-showers"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow"
        if (c >= 95) return "weather-storm"
        return "weather-none-available"
    }

    // ---------- fetching ----------
    // downloads go through curl (more reliable inside the panel than the built-in web requests)
    property int reqId: 0
    property var pending: ({})
    P5Support.DataSource {
        id: net
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const p = root.pending[source]
            net.disconnectSource(source)
            if (!p) return
            const c = Object.assign({}, root.pending); delete c[source]; root.pending = c
            if (data["exit code"] === 0) { try { p.cb(JSON.parse(data["stdout"])); return } catch (e) {} }
            if (p.fail) p.fail()
        }
    }
    function get(url, cb, fail) {
        reqId++
        const cmd = "curl -fsSL --max-time 15 -H 'User-Agent: MonsterWeather/1.0' '" + url.replace(/'/g, "%27") + "' #" + reqId
        const c = Object.assign({}, pending); c[cmd] = { cb: cb, fail: fail }; pending = c
        net.connectSource(cmd)
    }
    // three free "where am I" services, tried in turn
    function locate(i) {
        const c = Plasmoid.configuration
        const svc = [
            ["https://ipwho.is/?fields=success,city,country_code,latitude,longitude", j => j.success ? [j.latitude, j.longitude, j.city, j.country_code] : null],
            ["https://ipapi.co/json/", j => j.latitude ? [j.latitude, j.longitude, j.city, j.country_code] : null],
            ["https://get.geojs.io/v1/ip/geo.json", j => j.latitude ? [parseFloat(j.latitude), parseFloat(j.longitude), j.city || j.region, j.country_code] : null]
        ]
        if (i >= svc.length) { status = (c.latitude || c.longitude) ? status : "Couldn't find your town: press Change and type it"; if (c.latitude || c.longitude) load(); return }
        get(svc[i][0], j => {
            const r = svc[i][1](j)
            if (!r || !r[0]) { locate(i + 1); return }
            c.latitude = r[0]; c.longitude = r[1]; c.place = (r[2] || "Your area") + (r[3] ? ", " + r[3] : ""); place = c.place
            load()
        }, () => locate(i + 1))
    }
    function refresh() {
        const c = Plasmoid.configuration
        if (c.autoLocation || (!c.latitude && !c.longitude)) locate(0)
        else load()
    }
    function load() {
        const c = Plasmoid.configuration
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + c.latitude + "&longitude=" + c.longitude +
            "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day" +
            "&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
            "&timezone=auto&forecast_days=7&wind_speed_unit=kmh" + (f ? "&temperature_unit=fahrenheit" : "")
        get(url, j => {
            const k = j.current
            now = { temp: k.temperature_2m, feels: k.apparent_temperature, hum: k.relative_humidity_2m, wind: k.wind_speed_10m, code: k.weather_code, day: k.is_day === 1 }
            const start = j.hourly.time.findIndex(t => t >= k.time.slice(0, 13))
            const H = []
            for (let i = Math.max(0, start + 1); i < j.hourly.time.length && H.length < 12; i++)
                H.push({ t: j.hourly.time[i].slice(11, 13), temp: j.hourly.temperature_2m[i], code: j.hourly.weather_code[i], day: j.hourly.is_day[i] === 1 })
            hours = H
            const D = []
            for (let i = 0; i < j.daily.time.length; i++)
                D.push({ d: i === 0 ? "Today" : Qt.formatDate(new Date(j.daily.time[i] + "T12:00:00"), "ddd"), max: j.daily.temperature_2m_max[i], min: j.daily.temperature_2m_min[i], code: j.daily.weather_code[i], rain: j.daily.precipitation_probability_max[i] })
            days = D
            status = "Updated " + Qt.formatTime(new Date(), "hh:mm")
        }, () => { status = "Couldn't load the weather. Retrying soon" })
    }
    function search(q) {
        if (q.trim().length < 2) return
        searching = true
        get("https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&name=" + encodeURIComponent(q.trim()), j => {
            searching = false; results = (j.results || []).map(r => ({ name: r.name, area: [r.admin1, r.country].filter(x => x).join(", "), lat: r.latitude, lon: r.longitude, cc: r.country_code }))
        }, () => { searching = false; results = [] })
    }
    function choose(r) {
        const c = Plasmoid.configuration
        c.autoLocation = false; c.latitude = r.lat; c.longitude = r.lon; c.place = r.name + ", " + r.cc; place = c.place
        results = []; changing = false; load()
    }
    function useAuto() { Plasmoid.configuration.autoLocation = true; results = []; changing = false; refresh() }
    property bool changing: false

    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    onFChanged: load()

    // ---------- taskbar ----------
    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        onClicked: root.expanded = !root.expanded
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon { source: root.Plasmoid.icon; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth }
            PC3.Label { text: root.now ? Math.round(root.now.temp) + "°" : "–"; font.bold: true }
        }
    }

    // ---------- popup ----------
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        spacing: Kirigami.Units.largeSpacing

        // place
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon { source: "mark-location"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
            PC3.Label { Layout.fillWidth: true; text: root.place || "Finding your town…"; font.bold: true; elide: Text.ElideRight }
            PC3.ToolButton { text: root.changing ? "Done" : "Change"; onClicked: { root.changing = !root.changing; root.results = [] } }
            PC3.ToolButton { text: root.f ? "°F" : "°C"; onClicked: Plasmoid.configuration.fahrenheit = !Plasmoid.configuration.fahrenheit; PC3.ToolTip.text: "Switch °C / °F"; PC3.ToolTip.visible: hovered }
        }
        ColumnLayout {
            visible: root.changing
            Layout.fillWidth: true
            PC3.TextField {
                id: q; Layout.fillWidth: true; placeholderText: "Type a town and press Enter (e.g. Seoul)"
                onAccepted: root.search(text)
                Component.onCompleted: forceActiveFocus()
            }
            Repeater {
                model: root.results
                delegate: PC3.ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name + (modelData.area ? "  ·  " + modelData.area : "")
                    onClicked: root.choose(modelData)
                }
            }
            PC3.Label { visible: root.searching; text: "Searching…"; opacity: .7 }
            PC3.Button { text: "Find my town automatically"; icon.name: "find-location"; onClicked: root.useAuto() }
        }

        // now
        RowLayout {
            visible: !root.changing && root.now !== null
            Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon { source: root.now ? root.iconFor(root.now.code, root.now.day) : ""; Layout.preferredWidth: Kirigami.Units.iconSizes.huge; Layout.preferredHeight: Layout.preferredWidth }
            ColumnLayout {
                spacing: 0
                PC3.Label { text: root.now ? Math.round(root.now.temp) + root.unit : ""; font.pixelSize: Kirigami.Units.gridUnit * 2.6; font.weight: Font.Light }
                PC3.Label { text: root.now ? root.textFor(root.now.code) : ""; font.bold: true }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 2
                PC3.Label { text: root.now ? "Feels like " + Math.round(root.now.feels) + "°" : ""; opacity: .8 }
                PC3.Label { text: root.now ? "Humidity " + root.now.hum + "%" : ""; opacity: .8 }
                PC3.Label { text: root.now ? "Wind " + Math.round(root.now.wind) + " km/h" : ""; opacity: .8 }
            }
        }

        // next 12 hours
        Kirigami.Heading { visible: !root.changing && root.hours.length; level: 5; text: "Next 12 hours"; opacity: .7 }
        RowLayout {
            visible: !root.changing && root.hours.length
            Layout.fillWidth: true; spacing: 0
            Repeater {
                model: root.hours
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 2
                    PC3.Label { Layout.alignment: Qt.AlignHCenter; text: modelData.t; opacity: .7; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
                    Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: root.iconFor(modelData.code, modelData.day); Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth }
                    PC3.Label { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.temp) + "°"; font.bold: true }
                }
            }
        }

        // 7 days
        Kirigami.Heading { visible: !root.changing && root.days.length; level: 5; text: "7 days"; opacity: .7 }
        ColumnLayout {
            visible: !root.changing && root.days.length
            Layout.fillWidth: true; spacing: 4
            readonly property real lo: Math.min.apply(null, root.days.map(d => d.min))
            readonly property real hi: Math.max.apply(null, root.days.map(d => d.max))
            id: week
            Repeater {
                model: root.days
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                    PC3.Label { text: modelData.d; Layout.preferredWidth: Kirigami.Units.gridUnit * 3; font.bold: modelData.d === "Today" }
                    Kirigami.Icon { source: root.iconFor(modelData.code, true); Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Layout.preferredWidth }
                    PC3.Label { text: modelData.rain > 20 ? modelData.rain + "%" : ""; Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2; opacity: .75; color: Kirigami.Theme.linkColor }
                    PC3.Label { text: Math.round(modelData.min) + "°"; opacity: .7; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: Kirigami.Units.gridUnit * 2 }
                    Item {   // temperature range bar
                        Layout.fillWidth: true; Layout.preferredHeight: 6
                        Rectangle { anchors.fill: parent; radius: 3; color: Kirigami.Theme.textColor; opacity: .12 }
                        Rectangle {
                            radius: 3; height: parent.height
                            x: parent.width * (modelData.min - week.lo) / Math.max(1, week.hi - week.lo)
                            width: Math.max(6, parent.width * (modelData.max - modelData.min) / Math.max(1, week.hi - week.lo))
                            gradient: Gradient { orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#7fb7e6" } GradientStop { position: 1; color: "#a8e03a" } }
                        }
                    }
                    PC3.Label { text: Math.round(modelData.max) + "°"; font.bold: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 2 }
                }
            }
        }
        Item { Layout.fillHeight: true }
        PC3.Label { text: root.status + " · Open-Meteo"; opacity: .55; font.pixelSize: Kirigami.Theme.smallFont.pixelSize }
    }
}
