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
        SELECT id, group_id, name, icon, sort_order, archived_at FROM categories
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

    private static func mapCategory(_ row: Row) -> Category {
        Category(
            id: row.int(0),
            groupId: row.int(1),
            name: row.text(2) ?? "",
            icon: row.text(3),
            sortOrder: row.int(4),
            archivedAt: row.text(5)
        )
    }
}
