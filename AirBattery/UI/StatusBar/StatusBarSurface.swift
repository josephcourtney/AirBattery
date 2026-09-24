import AppKit
import SwiftUI

struct StatusBarBatteryContent: View {
    let item: iBattery
    let showMacBattery: Bool
    let colorfulBattery: Bool
    let iosBatteryStyle: Bool
    let batteryPercent: String
    let hideLevel: Int

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if item.hasBattery && showMacBattery {
                if batteryPercent == "outside", item.batteryLevel <= hideLevel {
                    Text("\(item.batteryLevel)%")
                        .font(.system(size: 11))
                }

                if iosBatteryStyle {
                    iosBattery
                } else {
                    macOSBattery
                }
            } else {
                Image("bolt.square.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
    }

    @ViewBuilder
    private var macOSBattery: some View {
        let width = round(max(2, min(19, Double(item.batteryLevel) / 100 * 19)))
        ZStack(alignment: .leading) {
            Image(
                colorfulBattery || batteryPercent == "inside"
                    ? "batt_outline_bold"
                    : "batt_outline"
            )

            if batteryPercent == "inside", item.batteryLevel <= hideLevel {
                StatusBarBatteryLevelContent(item: item)
                    .scaleEffect(0.9)
                    .foregroundColor(
                        colorfulBattery
                            ? Color(getPowerColor(ib2ab(item)))
                            : .primary
                    )
                    .offset(x: item.batteryLevel < 100 ? -1 : -0.5)
            } else {
                Rectangle()
                    .fill(
                        colorfulBattery
                            ? Color(getPowerColor(ib2ab(item)))
                            : (item.batteryLevel <= 10 ? .red : .primary)
                    )
                    .frame(width: width, height: 8, alignment: .leading)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 1.5,
                            style: .continuous
                        )
                    )
                    .offset(x: 2)

                if item.acPowered {
                    powerOverlay(xOffset: 6)
                }
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private var iosBattery: some View {
        ZStack(alignment: .leading) {
            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .frame(width: 27)
                .opacity(0.4)
                .mask {
                    HStack {
                        Spacer().frame(minWidth: 0)
                        Rectangle().frame(
                            width: min(
                                25,
                                CGFloat(100 - item.batteryLevel) / 100 * 27
                            )
                        )
                    }
                }

            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .foregroundColor(
                    colorfulBattery
                        ? Color(getPowerColor(ib2ab(item)) + "2")
                        : (item.batteryLevel <= 10 ? .red : .primary)
                )
                .frame(width: 27)
                .mask {
                    HStack {
                        Rectangle().frame(
                            width: max(
                                2,
                                CGFloat(item.batteryLevel) / 100 * 27
                            )
                        )
                        Spacer().frame(minWidth: 0)
                    }
                }

            if batteryPercent == "inside", item.batteryLevel <= hideLevel {
                if colorfulBattery {
                    StatusBarBatteryLevelContent(item: item)
                        .foregroundColor(.white)
                } else {
                    StatusBarBatteryLevelContent(item: item)
                        .foregroundColor(.white)
                        .blendMode(.destinationOut)
                }
            } else if item.acPowered {
                powerOverlay(xOffset: 6.5)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func powerOverlay(xOffset: CGFloat) -> some View {
        let name = "batt_" +
            ((item.isCharging || item.isCharged) ? "bolt" : "plug")
        Image(name + "_mask")
            .blendMode(.destinationOut)
            .offset(x: xOffset)
        Image(name)
            .offset(x: xOffset)
            .foregroundColor(.blackWhite)
    }
}

struct StatusBarBatteryLevelContent: View {
    let item: iBattery

    var body: some View {
        Group {
            if item.acPowered {
                HStack(spacing: -1) {
                    Text("\(item.batteryLevel)")
                        .font(
                            .system(
                                size: item.batteryLevel > 99 ? 10 : 11,
                                weight: .medium
                            )
                        )
                        .tracking(item.batteryLevel > 99 ? -0.3 : 0)
                        .offset(y: item.batteryLevel > 99 ? 0.4 : 0.5)

                    Image(
                        (item.isCharging || item.isCharged)
                            ? "bolt.fill"
                            : "powerplug.portrait.fill"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 5)
                    .padding(.leading, 1)
                    .offset(y: item.batteryLevel < 100 ? 0.5 : 0)
                }
                .offset(x: item.batteryLevel < 100 ? 0.5 : -0.5)
                .offset(
                    y: (item.acPowered && item.batteryLevel < 100) ? -0.5 : 0
                )
            } else {
                Text("\(item.batteryLevel)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .frame(maxHeight: 12, alignment: .center)
        .frame(maxWidth: 24, alignment: .center)
    }
}

struct SurfaceBatteryGlyph: View {
    let item: Device

    var body: some View {
        let width = round(
            max(1, min(19, Double(item.batteryLevel) / 100 * 19))
        )

        ZStack {
            ZStack(alignment: .leading) {
                Image("batt_outline_bold")
                Rectangle()
                    .fill(Color(getPowerColor(item)))
                    .frame(width: width, height: 8, alignment: .leading)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 1.5,
                            style: .continuous
                        )
                    )
                    .offset(x: 2)
            }

            if item.deviceID == "@MacInternalBattery" {
                if item.acPowered {
                    chargingOverlay(
                        isPlug: !(item.isCharging != 0 || item.isCharged)
                    )
                }
            } else if item.isCharging != 0 {
                chargingOverlay(isPlug: item.isCharging == 5)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func chargingOverlay(isPlug: Bool) -> some View {
        let name = "batt_" + (isPlug ? "plug" : "bolt")
        Image(name + "_mask")
            .blendMode(.destinationOut)
            .offset(x: -1.5)
        Image(name)
            .offset(x: -1.5)
            .foregroundColor(.blackWhite)
    }
}


