import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/memoire.dart';

class TimelineWidget extends StatelessWidget {
  final ScrollController scrollController;
  final List<Memoire> memoires;
  final Memoire? selectedMemoire;
  final Function(Memoire) onMemoireSelected;
  final Function(Memoire) onMemoireDoubleTapped;

  const TimelineWidget({
    super.key,
    required this.scrollController,
    required this.memoires,
    this.selectedMemoire,
    required this.onMemoireSelected,
    required this.onMemoireDoubleTapped,
  });

  @override
  Widget build(BuildContext context) {
    // Grouper par année
    final memoiresByYear = <String, List<Memoire>>{};
    for (var memoire in memoires) {
      final year = memoire.annee;
      memoiresByYear.putIfAbsent(year, () => []).add(memoire);
    }
    
    // Trier les années en ordre décroissant
    final sortedYears = memoiresByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: sortedYears.length,
        itemBuilder: (context, index) {
          final year = sortedYears[index];
          final yearMemoires = memoiresByYear[year]!
            ..sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
          
          return _buildYearSection(context, year, yearMemoires);
        },
      ),
    );
  }

  Widget _buildYearSection(BuildContext context, String year, List<Memoire> memoires) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête année
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              year,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3A52),
              ),
            ),
          ),
          
          // Ligne de temps verticale avec événements
          ...memoires.map((memoire) => _buildTimelineItem(context, memoire)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, Memoire memoire) {
    final isSelected = selectedMemoire?.id == memoire.id;
    final dateFormatter = DateFormat('dd MMM', 'fr_FR');
    
    return GestureDetector(
      onTap: () => onMemoireSelected(memoire),
      onDoubleTap: () => onMemoireDoubleTapped(memoire),
      child: Container(
        color: isSelected ? memoire.couleur.withOpacity(0.1) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne verticale + point
              SizedBox(
                width: 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 2,
                      height: 8,
                      color: Colors.grey[400],
                    ),
                    Container(
                      width: isSelected ? 16 : 12,
                      height: isSelected ? 16 : 12,
                      decoration: BoxDecoration(
                        color: memoire.couleur,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: memoire.couleur.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Contenu de la mémoire
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône + Titre
                    Row(
                      children: [
                        FaIcon(
                          memoire.icone,
                          size: 16,
                          color: memoire.couleur,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            memoire.titre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Date
                    Text(
                      dateFormatter.format(memoire.dateDebut),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    // Tags
                    if (memoire.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: memoire.tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: memoire.couleur.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: memoire.couleur,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
