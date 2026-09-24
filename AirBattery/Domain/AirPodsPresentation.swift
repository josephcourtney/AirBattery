import Foundation

struct AirPodsBatteryGroup: Hashable {
    let name: String
    let caseDevice: Device?
    let leftEarbud: Device?
    let rightEarbud: Device?
    let legacyMergedEarbuds: Device?

    var components: [Device] {
        var result = [caseDevice, leftEarbud, rightEarbud].compactMap { $0 }
        if leftEarbud == nil, rightEarbud == nil, let legacyMergedEarbuds {
            result.append(legacyMergedEarbuds)
        }
        return result
    }

    func mergedEarbudLevel(enabled: Bool, threshold: Int) -> Int? {
        guard let leftEarbud, let rightEarbud else { return nil }
        return EarbudMergePolicy.mergedLevel(
            enabled: enabled,
            threshold: threshold,
            leftLevel: leftEarbud.batteryLevel,
            leftCharging: leftEarbud.isCharging,
            rightLevel: rightEarbud.batteryLevel,
            rightCharging: rightEarbud.isCharging
        )
    }

    func mergedEarbudCharging(enabled: Bool, threshold: Int) -> Int? {
        guard let leftEarbud, let rightEarbud else { return nil }
        return EarbudMergePolicy.mergedCharging(
            enabled: enabled,
            threshold: threshold,
            leftLevel: leftEarbud.batteryLevel,
            leftCharging: leftEarbud.isCharging,
            rightLevel: rightEarbud.batteryLevel,
            rightCharging: rightEarbud.isCharging
        )
    }
}

struct BatteryComponentPresentation: Identifiable, Hashable {
    let role: BatteryComponentRole
    let device: Device

    var id: String {
        role.rawValue + ":" + device.deviceID
    }

    var label: String {
        DevicePresentationNaming.componentLabel(role)
    }

    var level: Int { device.batteryLevel }
    var charging: Int { device.isCharging }
}

struct LogicalDevicePresentation: Identifiable, Hashable {
    let id: String
    let displayName: String
    let compactName: String
    let representative: Device
    let components: [BatteryComponentPresentation]
    let newestUpdate: Double

}

enum AirPodsPresentation {
    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func baseName(for device: Device) -> String? {
        guard device.deviceType == "ap_case" || device.deviceType.hasPrefix("ap_pod") else {
            return nil
        }

        var name = device.deviceType.hasPrefix("ap_pod") && !device.parentName.isEmpty
            ? device.parentName
            : device.deviceName
        for suffix in [" (Case)", "（充电盒）", " 🄻🅁", " 🄻", " 🅁"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    static func group(for device: Device, in devices: [Device]) -> AirPodsBatteryGroup? {
        guard let baseName = baseName(for: device) else { return nil }
        let matching = devices.filter { candidate in
            guard let candidateBase = Self.baseName(for: candidate) else { return false }
            return normalizedName(candidateBase) == normalizedName(baseName)
        }

        let caseDevice = matching.first {
            $0.deviceType == "ap_case" &&
                ($0.deviceName.hasSuffix(" (Case)") || $0.deviceName.hasSuffix("（充电盒）"))
        }
        let left = matching.first { $0.deviceType == "ap_pod_left" }
        let right = matching.first { $0.deviceType == "ap_pod_right" }
        let legacyMerged = matching.first { $0.deviceType == "ap_pod_all" }

        guard caseDevice != nil || left != nil || right != nil || legacyMerged != nil else {
            return nil
        }
        return AirPodsBatteryGroup(
            name: baseName,
            caseDevice: caseDevice,
            leftEarbud: left,
            rightEarbud: right,
            legacyMergedEarbuds: legacyMerged
        )
    }


    private static func mergedAirPodsDevice(
        _ group: AirPodsBatteryGroup,
        level: Int,
        charging: Int
    ) -> Device {
        let source = group.leftEarbud ?? group.rightEarbud ?? group.caseDevice ?? group.legacyMergedEarbuds!
        let secondsRemaining = [group.leftEarbud, group.rightEarbud]
            .compactMap { $0?.estimatedSecondsRemaining }
            .min()
        return Device(
            deviceID: source.deviceID,
            deviceType: "ap_pod_all",
            deviceName: group.name,
            deviceModel: source.deviceModel,
            batteryLevel: level,
            isCharging: charging,
            parentName: group.name,
            lastUpdate: source.lastUpdate,
            mobileDeviceID: source.mobileDeviceID,
            bleDeviceID: source.bleDeviceID,
            batterySource: source.batterySource,
            estimatedSecondsRemaining: secondsRemaining
        )
    }

    static func logicalPresentations(
        from devices: [Device],
        mergeEarbuds: Bool,
        mergeThreshold: Int
    ) -> [LogicalDevicePresentation] {
        var result: [LogicalDevicePresentation] = []
        var consumedAirPods = Set<String>()

        for device in devices {
            if let baseName = baseName(for: device),
               let group = group(for: device, in: devices) {
                let key = normalizedName(baseName)
                guard consumedAirPods.insert(key).inserted else { continue }

                var components: [BatteryComponentPresentation] = []
                if let caseDevice = group.caseDevice {
                    components.append(
                        BatteryComponentPresentation(role: .caseBattery, device: caseDevice)
                    )
                }

                if let merged = group.mergedEarbudLevel(
                    enabled: mergeEarbuds,
                    threshold: mergeThreshold
                ) {
                    let charging = group.mergedEarbudCharging(
                        enabled: mergeEarbuds,
                        threshold: mergeThreshold
                    ) ?? 0
                    components.append(
                        BatteryComponentPresentation(
                            role: .earbuds,
                            device: mergedAirPodsDevice(
                                group,
                                level: merged,
                                charging: charging
                            )
                        )
                    )
                } else {
                    if let left = group.leftEarbud {
                        components.append(
                            BatteryComponentPresentation(role: .leftEarbud, device: left)
                        )
                    }
                    if let right = group.rightEarbud {
                        components.append(
                            BatteryComponentPresentation(role: .rightEarbud, device: right)
                        )
                    }
                    if group.leftEarbud == nil,
                       group.rightEarbud == nil,
                       let legacy = group.legacyMergedEarbuds {
                        components.append(
                            BatteryComponentPresentation(role: .earbuds, device: legacy)
                        )
                    }
                }

                guard let representative =
                    group.caseDevice ??
                    group.leftEarbud ??
                    group.rightEarbud ??
                    group.legacyMergedEarbuds
                else {
                    continue
                }

                result.append(
                    LogicalDevicePresentation(
                        id: "airpods:" + key,
                        displayName: group.name,
                        compactName: DevicePresentationNaming.compactName(
                            deviceType: representative.deviceType,
                            displayName: group.name
                        ),
                        representative: representative,
                        components: components,
                        newestUpdate: group.components.map(\.lastUpdate).max() ??
                            representative.lastUpdate
                    )
                )
                continue
            }

            result.append(
                LogicalDevicePresentation(
                    id: "device:" + device.deviceID + ":" + device.deviceName,
                    displayName: device.deviceName,
                    compactName: DevicePresentationNaming.compactName(
                        deviceType: device.deviceType,
                        displayName: device.deviceName
                    ),
                    representative: device,
                    components: [
                        BatteryComponentPresentation(role: .primary, device: device)
                    ],
                    newestUpdate: device.lastUpdate
                )
            )
        }

        return result
    }

    static func widgetLogicalPresentations(
        from devices: [Device]
    ) -> [LogicalDevicePresentation] {
        logicalPresentations(
            from: devices.filter(\.hasBattery),
            mergeEarbuds: false,
            mergeThreshold: 0
        )
    }

    static func widgetPresentationOrder(
        from devices: [Device]
    ) -> [Device] {
        widgetLogicalPresentations(from: devices)
            .flatMap(\.components)
            .map(\.device)
    }

    static func presentation(
        for device: Device,
        in devices: [Device],
        mergeEarbuds: Bool,
        mergeThreshold: Int
    ) -> LogicalDevicePresentation? {
        logicalPresentations(
            from: devices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        ).first {
            $0.components.contains(where: {
                $0.device.deviceID == device.deviceID &&
                $0.device.deviceType == device.deviceType
            }) ||
            $0.representative.deviceID == device.deviceID
        }
    }

    static func isSecondaryRow(_ device: Device, in devices: [Device]) -> Bool {
        guard let group = group(for: device, in: devices),
              let representative =
                group.caseDevice ??
                group.leftEarbud ??
                group.rightEarbud ??
                group.legacyMergedEarbuds
        else {
            return false
        }

        return !(
            representative.deviceID == device.deviceID &&
            representative.deviceType == device.deviceType &&
            representative.deviceName == device.deviceName
        )
    }
}
