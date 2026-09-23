//
//  GroupForm.swift
//  AirBattery
//

import SwiftUI

private let settingsLabelWidth: CGFloat = 210

struct SettingsPageHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SForm<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(
            maxWidth: 840,
            alignment: .topLeading
        )
    }
}

struct SGroupBox<Content: View>: View {
    var label: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if let label {
                GroupBox {
                    groupContent
                } label: {
                    Text(label).font(.headline)
                }
            } else {
                GroupBox {
                    groupContent
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupContent: some View {
        VStack(spacing: 3) {
            content()
        }
        .padding(.vertical, 1)
    }
}

struct SInfoButton: View {
    let tips: LocalizedStringKey
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .trailing, spacing: 12) {
                GroupBox {
                    Text(tips)
                        .padding(12)
                }
                Button("OK") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: LocalizedStringKey
    let tips: LocalizedStringKey?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
                if let tips {
                    SInfoButton(tips: tips)
                }
            }
            .frame(width: settingsLabelWidth, alignment: .trailing)

            control()
                .frame(minWidth: 116, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
    }
}

struct SButton: View {
    let title: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    let tips: LocalizedStringKey?
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        buttonTitle: LocalizedStringKey,
        tips: LocalizedStringKey? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.buttonTitle = buttonTitle
        self.tips = tips
        self.action = action
    }

    var body: some View {
        SettingsControlRow(title: title, tips: tips) {
            Button(buttonTitle, action: action)
        }
    }
}

struct SField: View {
    let title: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let tips: LocalizedStringKey?
    @Binding var text: String
    let width: Double

    init(
        _ title: LocalizedStringKey,
        placeholder: LocalizedStringKey = "",
        tips: LocalizedStringKey? = nil,
        text: Binding<String>,
        width: Double = .infinity
    ) {
        self.title = title
        self.placeholder = placeholder
        self.tips = tips
        _text = text
        self.width = width
    }

    var body: some View {
        SettingsControlRow(title: title, tips: tips) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: width)
        }
    }
}

struct SPicker<T: Hashable, Content: View, Style: PickerStyle>: View {
    let title: LocalizedStringKey
    @Binding var selection: T
    let style: Style
    let tips: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    init(
        _ title: LocalizedStringKey,
        selection: Binding<T>,
        style: Style = .menu,
        tips: LocalizedStringKey? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        _selection = selection
        self.style = style
        self.tips = tips
        self.content = content
    }

    var body: some View {
        SettingsControlRow(title: title, tips: tips) {
            Picker("", selection: $selection) {
                content()
            }
            .labelsHidden()
            .fixedSize()
            .pickerStyle(style)
        }
    }
}

struct SToggle: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    let tips: LocalizedStringKey?

    init(
        _ title: LocalizedStringKey,
        isOn: Binding<Bool>,
        tips: LocalizedStringKey? = nil
    ) {
        self.title = title
        _isOn = isOn
        self.tips = tips
    }

    var body: some View {
        SettingsControlRow(title: title, tips: tips) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct SSteper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let min: Int
    let max: Int
    let width: CGFloat
    let tips: LocalizedStringKey?

    init(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        min: Int = 0,
        max: Int = 100,
        width: CGFloat = 45,
        tips: LocalizedStringKey? = nil
    ) {
        self.title = title
        _value = value
        self.tips = tips
        self.width = width
        self.min = min
        self.max = max
    }

    private var clampedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { value = Swift.min(max, Swift.max(min, $0)) }
        )
    }

    var body: some View {
        SettingsControlRow(title: title, tips: tips) {
            HStack(spacing: 6) {
                TextField("", value: clampedValue, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: width)
                Stepper("", value: clampedValue, in: min...max)
                    .labelsHidden()
            }
        }
    }
}