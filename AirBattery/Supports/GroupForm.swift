//
//  GroupForm.swift
//  AirBattery
//

import SwiftUI

struct SForm<Content: View>: View {
    var spacing: CGFloat = 30
    var noSpacer = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
            if !noSpacer {
                Spacer(minLength: 0)
            }
        }
        .padding()
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
        VStack(spacing: 10) {
            content()
        }
        .padding(5)
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
                .font(.system(size: 15, weight: .light))
                .opacity(0.62)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .trailing) {
                GroupBox {
                    Text(tips).padding()
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
        LabeledContent {
            HStack(spacing: 4) {
                if let tips {
                    SInfoButton(tips: tips)
                }
                Button(buttonTitle, action: action)
            }
        } label: {
            Text(title)
        }
        .frame(minHeight: 28)
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
        LabeledContent {
            HStack(spacing: 4) {
                if let tips {
                    SInfoButton(tips: tips)
                }
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: width)
            }
        } label: {
            Text(title)
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
        LabeledContent {
            HStack(spacing: 4) {
                if let tips {
                    SInfoButton(tips: tips)
                }
                Picker("", selection: $selection) {
                    content()
                }
                .labelsHidden()
                .fixedSize()
                .pickerStyle(style)
            }
        } label: {
            Text(title)
        }
        .frame(minHeight: 28)
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
        LabeledContent {
            HStack(spacing: 4) {
                if let tips {
                    SInfoButton(tips: tips)
                }
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        } label: {
            Text(title)
        }
        .frame(minHeight: 28)
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
        LabeledContent {
            HStack(spacing: 4) {
                if let tips {
                    SInfoButton(tips: tips)
                }
                TextField("", value: clampedValue, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: width)
                Stepper("", value: clampedValue, in: min...max)
                    .labelsHidden()
            }
        } label: {
            Text(title)
        }
        .frame(minHeight: 28)
    }
}
