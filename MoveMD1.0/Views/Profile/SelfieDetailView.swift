import SwiftUI
import SwiftData

struct SelfieDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var errorManager: ErrorManager
    
    let selfie: ProgressSelfie
    @Bindable var user: User 
    
    @State private var showingDeleteConfirmAlert = false

    var themeColor: Color = .blue 

    var body: some View {
        NavigationView { 
            VStack {
                if let uiImage = UIImage(data: selfie.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("Could not load image.")
                        .foregroundColor(.red)
                }
                
                Spacer() 
                
                // Button {
                //     showingDeleteConfirmAlert = true
                // } label: {
                //     Label("Delete Selfie", systemImage: "trash")
                //         .foregroundColor(.red)
                //         .padding()
                //         .frame(maxWidth: .infinity)
                //         .background(Color.red.opacity(0.1))
                //         .clipShape(Capsule())
                // }
                // .padding(.horizontal)
                // .padding(.bottom)
            }
            .navigationTitle(selfie.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { 
                    Button("Close") {
                        dismiss()
                    }
                    .tint(themeColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingDeleteConfirmAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red) 
                }
            }
            .alert("Delete Progress Picture?", isPresented: $showingDeleteConfirmAlert) {
                Button("Delete", role: .destructive) {
                    deleteSelfie()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this progress picture from \(selfie.displayName)? This action cannot be undone.")
            }
        }
        .tint(themeColor) 
    }
    
    private func deleteSelfie() {
        if let index = user.progressSelfies.firstIndex(where: { $0.id == selfie.id }) {
            user.progressSelfies.remove(at: index)
            do {
                try modelContext.save() 
                print("Picture \(selfie.displayName) deleted successfully.")
                dismiss()
            } catch {
                print("Error saving context after deleting picture: \(error.localizedDescription)")
                errorManager.presentAlert(title: "Deletion Failed", message: "Could not save the change after removing the picture. Please try again. Error: \(error.localizedDescription)")
            }
        } else {
            print("Error: Picture to delete not found in user's collection.")
            errorManager.presentAlert(title: "Deletion Error", message: "An unexpected error occurred. The picture could not be found for deletion.")
        }
    }
}
