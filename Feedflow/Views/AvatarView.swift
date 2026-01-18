import SwiftUI

struct AvatarView: View {
    let urlOrName: String
    let size: CGFloat
    
    var body: some View {
        if urlOrName.starts(with: "http") {
            AsyncImage(url: URL(string: urlOrName)) { phase in
                switch phase {
                case .empty:
                    Color.gray
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "person.circle.fill").resizable()
                @unknown default:
                    Color.gray
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Image(systemName: urlOrName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .foregroundColor(.gray)
        }
    }
}
