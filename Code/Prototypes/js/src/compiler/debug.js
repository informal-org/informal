

export function aSummaryTree(node) {
    // Convert an ASTNode into a summarized tree with just the relevant info. 
    return {
        node_type: node.node_type,
        operator: node.operator ? node.operator.keyword : null,
        value: Array.isArray(node.value) ? node.value.map(aSummaryTree) : node.value,
        left: node.left ? aSummaryTree(node.left) : node.left,
        right: node.right ? aSummaryTree(node.right) : node.right,
    }
}