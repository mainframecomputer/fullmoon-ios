import Contacts
import ContactsUI
import SwiftUI

#if os(iOS) || os(visionOS)

/// Presents the system contact picker without requesting full address-book access.
struct NoctisContactPicker: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactNicknameKey
        ]
        return picker
    }

    func updateUIViewController(
        _ controller: CNContactPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}

#endif
