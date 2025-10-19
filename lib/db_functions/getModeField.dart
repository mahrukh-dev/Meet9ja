
// Helper method to get mode field name
String getModeField(String selectedMode) {
  switch (selectedMode) {
    case 'Date': return 'date';
    case 'Travel partner': return 'travel_partner';
    case 'BFF': return 'BFF';
    case 'Bizz': return 'bizz';
    default: return 'travel_partner';
  }
}