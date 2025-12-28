#!/usr/bin/env python3
import json
from icalendar import Calendar
from datetime import datetime, date
from pathlib import Path
import sys

def normalize_date(dt):
    """Convertit date ou datetime en datetime naive pour comparaison"""
    if isinstance(dt, datetime):
        if dt.tzinfo is not None:
            return dt.replace(tzinfo=None)
        return dt
    elif isinstance(dt, date):
        return datetime.combine(dt, datetime.min.time())
    return dt

def parse_single_trip_ics(filepath):
    """Parse un fichier ICS représentant un voyage complet"""
    with open(filepath, 'rb') as f:
        cal = Calendar.from_ical(f.read())
    
    trip_name = None
    events = []
    
    for component in cal.walk('VEVENT'):
        summary = str(component.get('SUMMARY', ''))
        start = component.get('DTSTART').dt
        end = component.get('DTEND').dt
        location = str(component.get('LOCATION', ''))
        description = str(component.get('DESCRIPTION', ''))
        
        if not trip_name and summary:
            trip_name = summary
        
        start = normalize_date(start)
        end = normalize_date(end)
        
        geo = component.get('GEO')
        lat, lng = None, None
        if geo:
            lat, lng = float(geo.latitude), float(geo.longitude)
        
        event = {
            'summary': summary,
            'start': start,
            'end': end,
            'location': location,
            'description': description,
            'latitude': lat,
            'longitude': lng
        }
        events.append(event)
    
    return trip_name, sorted(events, key=lambda x: x['start'])

def classify_event_type(description):
    """Détermine le type d'événement"""
    desc_lower = description.lower()
    if 'lodging' in desc_lower or 'hotel' in desc_lower:
        return 'lodging'
    elif 'air' in desc_lower or 'flight' in desc_lower:
        return 'air'
    elif 'rail' in desc_lower or 'train' in desc_lower:
        return 'rail'
    elif 'car' in desc_lower:
        return 'car'
    elif 'activity' in desc_lower:
        return 'activity'
    elif 'restaurant' in desc_lower or 'dining' in desc_lower:
        return 'restaurant'
    return 'other'

def merge_lodging_events(events):
    """
    Fusionne les check-in et check-out d'un même hébergement
    en un seul événement "séjour"
    """
    lodging_events = [e for e in events if classify_event_type(e['description']) == 'lodging']
    non_lodging_events = [e for e in events if classify_event_type(e['description']) != 'lodging']
    
    # Grouper les lodgings par lieu
    lodging_by_location = {}
    for event in lodging_events:
        loc_key = (event['location'], event['latitude'], event['longitude'])
        if loc_key not in lodging_by_location:
            lodging_by_location[loc_key] = []
        lodging_by_location[loc_key].append(event)
    
    # Créer des événements "séjour" fusionnés
    merged_lodgings = []
    for (location, lat, lng), events_list in lodging_by_location.items():
        # Trouver la première arrivée et le dernier départ
        check_in = min(e['start'] for e in events_list)
        check_out = max(e['end'] for e in events_list)
        
        # Prendre le premier summary (souvent le nom de l'hôtel)
        summary = events_list[0]['summary']
        
        merged_event = {
            'summary': summary,
            'start': check_in,
            'end': check_out,
            'location': location,
            'description': 'Lodging',
            'latitude': lat,
            'longitude': lng,
            'merged': True  # Flag pour savoir que c'est fusionné
        }
        merged_lodgings.append(merged_event)
    
    # Combiner lodgings fusionnés + autres événements
    all_events = merged_lodgings + non_lodging_events
    return sorted(all_events, key=lambda x: x['start'])

def extract_voyage_from_events(trip_name, events, filename):
    """Crée un objet voyage à partir des événements"""
    
    if not events:
        return None
    
    # Fusionner les check-in/check-out
    events = merge_lodging_events(events)
    
    # Dates globales
    date_debut = min(e['start'] for e in events)
    date_fin = max(e['end'] for e in events)
    
    # Transformer tous les événements en "mémoires"
    evenements = []
    for event in events:
        evt_type = classify_event_type(event['description'])
        
        evenement = {
            "type": evt_type,
            "nom": event['summary'],
            "lieu": event['location'] if event['location'] else None,
            "dateDebut": event['start'].strftime('%Y-%m-%d'),
        }
        
        # Ajouter dateFin seulement si différente de dateDebut
        if event['end'].date() != event['start'].date():
            evenement['dateFin'] = event['end'].strftime('%Y-%m-%d')
        
        # Ajouter coordonnées si disponibles
        if event['latitude'] and event['longitude']:
            evenement['lat'] = event['latitude']
            evenement['lng'] = event['longitude']
        
        evenements.append(evenement)
    
    # Calculer le barycentre sur TOUS les événements géolocalisés
    geo_events = [e for e in events if e['latitude'] and e['longitude']]
    if geo_events:
        lat_mean = sum(e['latitude'] for e in geo_events) / len(geo_events)
        lng_mean = sum(e['longitude'] for e in geo_events) / len(geo_events)
    else:
        lat_mean, lng_mean = 0.0, 0.0
    
    # Nom du voyage
    nom_voyage = trip_name if trip_name else Path(filename).stem
    
    # Déterminer le type basé sur les lieux uniques
    lieux_uniques = set(e['location'] for e in events if e['location'])
    type_voyage = "circuit" if len(lieux_uniques) > 2 else "ville" if len(lieux_uniques) > 0 else "autre"
    
    voyage = {
        "id": Path(filename).stem,
        "nom": nom_voyage,
        "latitude": lat_mean,
        "longitude": lng_mean,
        "dateDebut": date_debut.strftime('%Y-%m-%d'),
        "dateFin": date_fin.strftime('%Y-%m-%d'),
        "type": type_voyage,
        "description": f"Voyage du {date_debut.strftime('%d/%m/%Y')} au {date_fin.strftime('%d/%m/%Y')}",
        "participants": ["Matt"],
        "photos": [],
        "evenements": evenements
    }
    
    return voyage

def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_tripit.py fichier1.ics [fichier2.ics ...]")
        print("   ou: python convert_tripit.py *.ics")
        sys.exit(1)
    
    voyages = []
    
    for filepath in sys.argv[1:]:
        print(f"\n📄 Traitement de {filepath}...")
        try:
            trip_name, events = parse_single_trip_ics(filepath)
            print(f"  ✓ Nom du voyage: {trip_name}")
            print(f"  ✓ {len(events)} événements trouvés")
            
            # Afficher les types d'événements détectés
            types = {}
            for e in events:
                evt_type = classify_event_type(e['description'])
                types[evt_type] = types.get(evt_type, 0) + 1
            print(f"  ✓ Types: {dict(types)}")
            
            voyage = extract_voyage_from_events(trip_name, events, filename=filepath)
            if voyage:
                voyages.append(voyage)
                print(f"  ✓ Voyage créé avec {len(voyage['evenements'])} événements (après fusion)")
            
        except Exception as e:
            print(f"  ✗ Erreur: {e}")
            import traceback
            traceback.print_exc()
    
    # Sauvegarder
    result = {"voyages": voyages}
    with open('voyages_converted.json', 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ Fichier généré: voyages_converted.json")
    print(f"✅ {len(voyages)} voyages convertis")
    print("\n💡 Vérifiez le JSON généré et ajustez:")
    print("   - Les participants")
    print("   - Les descriptions des événements")
    print("   - Les types si nécessaire")

if __name__ == '__main__':
    main()
