import SwiftUI

struct ItemsTable: View {
    let items: [Item]

    var body: some View {
        Table(items) {
            TableColumn("ID") { item in
                Text("\(item.id)")
                    .monospacedDigit()
            }
            .width(50)

            TableColumn("Name", value: \.name)
                .width(min: 100, ideal: 150)

            TableColumn("Description", value: \.description)

            TableColumn("Price") { item in
                Text(item.price, format: .currency(code: "USD"))
                    .monospacedDigit()
            }
            .width(80)
        }
    }
}
