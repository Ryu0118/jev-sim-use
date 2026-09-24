/// Everything Jev may choose from on one screen: operations, and the targets each one needs.
package struct ActionMenu: Sendable, Hashable {
    /// Operations offered, in presentation order; each has the targets it needs.
    package var operations: [Operation]
    /// Elements a tap or a gesture may act on.
    package var elements: [ElementTarget]
    /// Editable fields `enterText` may type into.
    package var fields: [ElementTarget]
    /// Named texts `enterText` may type.
    package var texts: [InputText]

    package init(operations: [Operation], elements: [ElementTarget], fields: [ElementTarget], texts: [InputText]) {
        self.operations = operations
        self.elements = elements
        self.fields = fields
        self.texts = texts
    }
}
