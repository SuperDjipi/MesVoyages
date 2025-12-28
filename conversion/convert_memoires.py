#!/usr/bin/env python3
import json

def convert_voyages_to_memoires(input_file, output_file):
    """Convertit le format voyages vers le format mémoires unifié"""
    
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    memoires = []
    
    for voyage in data.get('voyages', []):
        memoire = {
            "id": voyage['id'],
            "categorie": "voyage",
            "titre": voyage['nom'],
            "dateDebut": voyage['dateDebut'],
            "dateFin": voyage['dateFin'],
            "latitude": voyage['latitude'],
            "longitude": voyage['longitude'],
            "description": voyage['description'],
            "participants": voyage['participants'],
            "photos": voyage.get('photos', []),
            "tags": [voyage['type']],  # Le type devient un tag
        }
        
        # Ajouter les événements si présents
        if 'evenements' in voyage and voyage['evenements']:
            memoire['evenements'] = voyage['evenements']
        
        memoires.append(memoire)
    
    result = {"memoires": memoires}
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Conversion terminée : {len(memoires)} mémoires créées")
    print(f"✅ Fichier généré : {output_file}")

if __name__ == '__main__':
    convert_voyages_to_memoires('voyages_converted.json', 'memoires.json')
