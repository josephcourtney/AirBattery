//
//  GroupForm.swift
//  AirBattery
//

import SwiftUI

private let settingsLabelWidth: CGFloat = 200

struct SForm<Content: View>: View {
    var spacing: CGFloat = 20
    var noSpacer = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
            if !noSpacer {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SGroupBox<Content: View>: View {
    var label: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    var body: some View {
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

    private var groupContent: some View {
        VStack(spacing: 6) {
            content()
        }
        .padding(.vertical, 2)
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
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                Text(title)
                    .multilineTextAlignment(.trailing)
                if let tips {
                    SInfoButton(tips: tips)
                }
            }
            .frame(width: settingsLabelWidth, alignment: .trailing)

            control()
                .frame(minWidth: 120, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 26)
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
