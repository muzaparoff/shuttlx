import SwiftUI
import Contacts

struct InviteMembersView: View {
    @StateObject private var viewModel = InviteMembersViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let team: Team
    
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingContactsPicker = false
    @State private var showingInviteSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Invite Method", selection: $selectedTab) {
                    Text("Search Users").tag(0)
                    Text("Contacts").tag(1)
                    Text("Link").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Bar
                if selectedTab == 0 {
                    SearchBar(text: $searchText, placeholder: "Search by username or email")
                        .padding(.horizontal)
                }
                
                // Content
                TabView(selection: $selectedTab) {
                    // Search Users Tab
                    searchUsersView
                        .tag(0)
                    
                    // Contacts Tab
                    contactsView
                        .tag(1)
                    
                    // Invite Link Tab
                    inviteLinkView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 && !viewModel.selectedUsers.isEmpty {
                        Button("Send (\(viewModel.selectedUsers.count))") {
                            Task {
                                await viewModel.sendInvitations(to: Array(viewModel.selectedUsers), for: team)
                                showingInviteSuccess = true
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .onAppear {
                viewModel.loadSuggestedUsers()
            }
            .onChange(of: searchText) { newValue in
                viewModel.searchUsers(query: newValue)
            }
            .alert("Invitations Sent", isPresented: $showingInviteSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your invitations have been sent successfully!")
            }
        }
    }
    
    private var searchUsersView: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                suggestedUsersSection
            } else {
                searchResultsSection
            }
        }
    }
    
    private var suggestedUsersSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !viewModel.suggestedUsers.isEmpty {
                    SectionHeaderView(title: "Suggested")
                    
                    ForEach(viewModel.suggestedUsers) { user in
                        UserRowView(
                            user: user,
                            isSelected: viewModel.selectedUsers.contains(user.id),
                            team: team
                        ) {
                            viewModel.toggleUserSelection(user)
                        }
                        .padding(.horizontal)
                    }
                }
                
                if !viewModel.recentlyActive.isEmpty {
                    SectionHeaderView(title: "Recently Active")
                    
                    ForEach(viewModel.recentlyActive) { user in
                        UserRowView(
                            user: user,
                            isSelected: viewModel.selectedUsers.contains(user.id),
                            team: team
                        ) {
                            viewModel.toggleUserSelection(user)
                        }
                        .padding(.horizontal)
                    }
                }
                
                if viewModel.suggestedUsers.isEmpty && viewModel.recentlyActive.isEmpty {
                    EmptyStateView(
                        icon: "person.2.fill",
                        title: "No Suggestions",
                        message: "Search for users by username or email to invite them to your team."
                    )
                    .padding()
                }
            }
        }
    }
    
    private var searchResultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No users found matching '\(searchText)'"
                    )
                    .padding()
                } else {
                    ForEach(viewModel.searchResults) { user in
                        UserRowView(
                            user: user,
                            isSelected: viewModel.selectedUsers.contains(user.id),
                            team: team
                        ) {
                            viewModel.toggleUserSelection(user)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private var contactsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Invite from Contacts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select contacts to invite them to join your team. They'll receive an invitation via email or text message.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Select Contacts") {
                showingContactsPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            if !viewModel.selectedContacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Contacts (\(viewModel.selectedContacts.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.selectedContacts, id: \.identifier) { contact in
                                ContactRowView(contact: contact) {
                                    viewModel.removeContact(contact)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    
                    Button("Send Invitations") {
                        Task {
                            await viewModel.sendContactInvitations(for: team)
                            showingInviteSuccess = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .disabled(viewModel.isLoading)
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingContactsPicker) {
            ContactsPickerView { contacts in
                viewModel.addContacts(contacts)
            }
        }
    }
    
    private var inviteLinkView: some View {
        VStack(spacing: 24) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Share Invite Link")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Share this link with anyone you'd like to invite to your team. The link expires in 7 days.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.inviteLink)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button("Copy") {
                        UIPasteboard.general.string = viewModel.inviteLink
                        viewModel.showCopiedFeedback()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                if viewModel.linkCopied {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Link copied!")
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }
            }
            
            HStack(spacing: 16) {
                Button("Share") {
                    viewModel.shareInviteLink()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("Regenerate") {
                    Task {
                        await viewModel.regenerateInviteLink(for: team)
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Link Statistics")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Views")
                        Text("\(viewModel.linkViews)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Joins")
                        Text("\(viewModel.linkJoins)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await viewModel.loadInviteLink(for: team)
            }
        }
    }
}

struct UserRowView: View {
    let user: User
    let isSelected: Bool
    let team: Team
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Text(user.initials)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                if let username = user.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let mutualFriends = user.mutualFriendsCount, mutualFriends > 0 {
                    Text("\(mutualFriends) mutual friends")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            if team.memberIDs.contains(user.id) {
                Text("Member")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            } else {
                Button(action: onTap) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .green : .blue)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !team.memberIDs.contains(user.id) {
                onTap()
            }
        }
    }
}

struct ContactRowView: View {
    let contact: CNContact
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(contact.givenName.prefix(1) + contact.familyName.prefix(1))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(contact.givenName) \(contact.familyName)")
                    .font(.headline)
                
                if let email = contact.emailAddresses.first?.value as String? {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Remove") {
                onRemove()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// Contact Picker Implementation
struct ContactsPickerView: UIViewControllerRepresentable {
    let onContactsSelected: ([CNContact]) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onContactsSelected: onContactsSelected)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let onContactsSelected: ([CNContact]) -> Void
        
        init(onContactsSelected: @escaping ([CNContact]) -> Void) {
            self.onContactsSelected = onContactsSelected
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onContactsSelected(contacts)
        }
    }
}

#Preview {
    InviteMembersView(team: Team(
        id: "team1",
        name: "Sample Team",
        description: "A sample team for preview",
        ownerID: "user1",
        memberIDs: ["user1"],
        isPrivate: false,
        createdAt: Date(),
        category: .fitness
    ))
}
