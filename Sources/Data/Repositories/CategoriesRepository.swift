import Foundation

/// CRUD for `category_groups` + `categories`. Management is inline on the
/// Budget screen (no separate Manage Categories page) per the current UX —
/// see docs/design/uiux/budget.md.
final class CategoriesRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    func groups() -> [CategoryGroup] {
        database.query(
            "SELECT id, name, sort_order FROM category_groups ORDER BY sort_order, name",
            row: { CategoryGroup(id: $0.int(0), name: $0.text(1) ?? "", sortOrder: $0.int(2)) }
        )
    }

    func categories(includeArchived: Bool = false) -> [Category] {
        let sql = """
        SELECT id, group_id, name, icon, sort_order, archived_at, target_cents, target_type FROM categories
        \(includeArchived ? "" : "WHERE archived_at IS NULL")
        ORDER BY sort_order, name
        """
        return database.query(sql, row: Self.mapCategory)
    }

    @discardableResult
    func createGroup(name: String) -> Int {
        let nextOrder = (database.query("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM category_groups", row: { $0.int(0) }).first ?? 0)
        return Int(database.run("INSERT INTO category_groups (name, sort_order) VALUES (?, ?)", [name, nextOrder]))
    }

    func renameGroup(id: Int, name: String) {
        database.run("UPDATE category_groups SET name = ? WHERE id = ?", [name, id])
    }

    func deleteGroup(id: Int) {
        database.run("DELETE FROM categories WHERE group_id = ?", [id])
        database.run("DELETE FROM category_groups WHERE id = ?", [id])
    }

    /// Swaps sort_order with the group immediately above/below — the
    /// original settled on Move Up/Down over drag gestures; see
    /// docs/DESIGN.md's Phase 5 note on `react-native-gesture-handler`.
    func moveGroup(id: Int, direction: MoveDirection) {
        let ordered = groups()
        guard let index = ordered.firstIndex(where: { $0.id == id }) else { return }
        let swapIndex = direction == .up ? index - 1 : index + 1
        guard ordered.indices.contains(swapIndex) else { return }
        database.run("UPDATE category_groups SET sort_order = ? WHERE id = ?", [ordered[swapIndex].sortOrder, ordered[index].id])
        database.run("UPDATE category_groups SET sort_order = ? WHERE id = ?", [ordered[index].sortOrder, ordered[swapIndex].id])
    }

    func moveCategory(id: Int, direction: MoveDirection) {
        guard let category = categories().first(where: { $0.id == id }) else { return }
        let siblings = categories().filter { $0.groupId == category.groupId }
        guard let index = siblings.firstIndex(where: { $0.id == id }) else { return }
        let swapIndex = direction == .up ? index - 1 : index + 1
        guard siblings.indices.contains(swapIndex) else { return }
        database.run("UPDATE categories SET sort_order = ? WHERE id = ?", [siblings[swapIndex].sortOrder, siblings[index].id])
        database.run("UPDATE categories SET sort_order = ? WHERE id = ?", [siblings[index].sortOrder, siblings[swapIndex].id])
    }

    @discardableResult
    func createCategory(groupId: Int, name: String, icon: String?) -> Int {
        let nextOrder = (database.query(
            "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM categories WHERE group_id = ?",
            [groupId],
            row: { $0.int(0) }
        ).first ?? 0)
        return Int(database.run(
            "INSERT INTO categories (group_id, name, icon, sort_order) VALUES (?, ?, ?, ?)",
            [groupId, name, icon, nextOrder]
        ))
    }

    func rename(categoryId: Int, name: String, icon: String?) {
        database.run("UPDATE categories SET name = ?, icon = ? WHERE id = ?", [name, icon, categoryId])
    }

    func archive(categoryId: Int) {
        database.run("UPDATE categories SET archived_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?", [categoryId])
    }

    /// Monthly funding target — see docs/DESIGN.md's Category targets
    /// backlog item. `nil` cents clears the target.
    func setTarget(categoryId: Int, monthlyCents: Int?) {
        database.run(
            "UPDATE categories SET target_cents = ?, target_type = ? WHERE id = ?",
            [monthlyCents, monthlyCents == nil ? nil : CategoryTargetType.monthly.rawValue, categoryId]
        )
    }

    private static func mapCategory(_ row: Row) -> Category {
        Category(
            id: row.int(0),
            groupId: row.int(1),
            name: row.text(2) ?? "",
            icon: row.text(3),
            sortOrder: row.int(4),
            archivedAt: row.text(5),
            targetCents: row.isNull(6) ? nil : row.int(6),
            targetType: row.text(7).flatMap(CategoryTargetType.init(rawValue:))
        )
    }
}

enum MoveDirection {
    case up, down
}
