import 'package:flutter/material.dart';

class AdminDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<Map<String, dynamic>> rows;
  final List<String> propertyKeys;
  final Function(int)? onRowTap;
  final List<Widget>? Function(Map<String, dynamic> row)? rowActions;
  final bool isLoading;
  final int totalRows;
  final int currentPage;
  final int rowsPerPage;
  final void Function(int)? onPageChanged;
  final String? searchQuery;
  final void Function(String)? onSearchChanged;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.propertyKeys,
    this.onRowTap,
    this.rowActions,
    this.isLoading = false,
    this.totalRows = 0,
    this.currentPage = 0,
    this.rowsPerPage = 20,
    this.onPageChanged,
    this.searchQuery,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barre de recherche
        if (onSearchChanged != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: onSearchChanged,
              controller: TextEditingController(text: searchQuery),
            ),
          ),
        // Tableau
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const Center(child: Text('Aucune donnée'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: columns,
                        rows: List.generate(rows.length, (index) {
                          final row = rows[index];
                          return DataRow(
                            onSelectChanged: onRowTap != null ? (_) => onRowTap!(index) : null,
                            cells: [
                              ...propertyKeys.map((key) {
                                dynamic value = row[key];
                                if (value is DateTime) {
                                  value = '${value.day}/${value.month}/${value.year}';
                                }
                                return DataCell(Text(value?.toString() ?? ''));
                              }),
                              if (rowActions != null)
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rowActions!(row) ?? [],
                                )),
                            ],
                          );
                        }),
                      ),
                    ),
        ),
        // Pagination
        if (totalRows > 0 && onPageChanged != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: currentPage > 0 ? () => onPageChanged!(currentPage - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page ${currentPage + 1} / ${((totalRows - 1) ~/ rowsPerPage) + 1}'),
                IconButton(
                  onPressed: (currentPage + 1) * rowsPerPage < totalRows
                      ? () => onPageChanged!(currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
