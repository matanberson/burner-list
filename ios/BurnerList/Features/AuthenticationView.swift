import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var app: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var creatingAccount = false
    @State private var working = false

    var body: some View {
        ZStack {
            BurnerTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("🍳 Burner List 🔥")
                        .font(BurnerTheme.heading(32))
                        .foregroundStyle(BurnerTheme.textDark)
                    Text("Work through your day focusing on your two important things")
                        .font(BurnerTheme.body(13))
                        .foregroundStyle(BurnerTheme.textSoft)
                        .padding(.top, 3)
                        .padding(.bottom, 28)

                    HStack(spacing: 22) {
                        authTab("Sign in", selected: !creatingAccount) { creatingAccount = false }
                        authTab("Sign up", selected: creatingAccount) { creatingAccount = true }
                        Spacer()
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(BurnerTheme.border).frame(height: 1)
                    }
                    .padding(.bottom, 20)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(BurnerFieldStyle())
                        .padding(.bottom, 10)

                    SecureField("Password", text: $password)
                        .textContentType(creatingAccount ? .newPassword : .password)
                        .textFieldStyle(BurnerFieldStyle())

                    if let message = app.message {
                        Text(message)
                            .font(BurnerTheme.body(13))
                            .foregroundStyle(BurnerTheme.danger)
                            .padding(.top, 10)
                    }

                    Button(creatingAccount ? "Create account" : "Sign in") { submitEmail() }
                        .buttonStyle(BurnerPrimaryButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || working)
                        .opacity(email.isEmpty || password.isEmpty || working ? 0.55 : 1)
                        .padding(.top, 14)

                    HStack {
                        Rectangle().fill(BurnerTheme.border).frame(height: 1)
                        Text("or").font(BurnerTheme.body(12)).foregroundStyle(BurnerTheme.textFaint)
                        Rectangle().fill(BurnerTheme.border).frame(height: 1)
                    }
                    .padding(.vertical, 17)

                    Button { submitGoogle() } label: {
                        HStack(spacing: 9) {
                            Text("G").font(BurnerTheme.body(16, weight: .bold)).foregroundStyle(.blue)
                            Text("Continue with Google")
                                .font(BurnerTheme.body(14))
                                .foregroundStyle(BurnerTheme.textDark)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(BurnerTheme.border))
                    }
                    .disabled(working)
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.top, 90)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func authTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BurnerTheme.body(14))
                .foregroundStyle(selected ? BurnerTheme.textDark : BurnerTheme.textFaint)
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(selected ? BurnerTheme.textMid : .clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func submitEmail() {
        Task {
            working = true
            if creatingAccount { await app.signUp(email: email, password: password) }
            else { await app.signIn(email: email, password: password) }
            working = false
        }
    }

    private func submitGoogle() {
        Task {
            working = true
            await app.signInWithGoogle()
            working = false
        }
    }
}
