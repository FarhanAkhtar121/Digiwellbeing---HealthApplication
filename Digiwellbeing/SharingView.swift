import SwiftUI

struct Caretaker: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var contact: String // email or phone
}

struct SharingView: View {
    @ObservedObject private var authManager = AuthManager.shared

    @State private var caretakers: [Caretaker] = [
        // start empty; demo users could be added here
    ]
    @State private var name: String = ""
    @State private var contact: String = ""
    @State private var showLimitAlert = false

    private let maxCaretakers = 3

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { authManager.signOut() }

                if let username = authManager.userName {
                    Text("Welcome, \(username)!")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // Title
                HStack {
                    Image(systemName: "person.2.fill").foregroundColor(.blue)
                    Text("Sharing").font(.largeTitle).bold()
                    Spacer()
                }
                .padding(.horizontal)

                // Add caretaker form
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.blue)
                        Text("Add a caretaker (max \(maxCaretakers))")
                            .font(.headline)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        TextField("Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Email or phone", text: $contact)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            addCaretaker()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || contact.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding(.horizontal)

                // List caretakers
                List {
                    Section(header: Text("Caretakers")) {
                        if caretakers.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("No caretakers added yet.")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ForEach(caretakers) { person in
                                HStack {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 28)
                                    VStack(alignment: .leading) {
                                        Text(person.name).font(.headline)
                                        Text(person.contact).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .onDelete(perform: deleteCaretakers)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .padding(.top)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBlue).opacity(0.06)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .alert("Limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can add up to \(maxCaretakers) caretakers.")
            }
        }
    }

    private func addCaretaker() {
        guard caretakers.count < maxCaretakers else {
            showLimitAlert = true
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedContact.isEmpty else { return }
        let new = Caretaker(name: trimmedName, contact: trimmedContact)
        withAnimation {
            caretakers.append(new)
        }
        name = ""
        contact = ""
    }

    private func deleteCaretakers(at offsets: IndexSet) {
        withAnimation { caretakers.remove(atOffsets: offsets) }
    }
}

struct SharingView_Previews: PreviewProvider {
    static var previews: some View {
        SharingView()
    }
}
