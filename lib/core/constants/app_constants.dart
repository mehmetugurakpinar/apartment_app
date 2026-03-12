class AppConstants {
  // Maintenance priorities
  static const Map<String, String> priorities = {
    'emergency': 'Emergency',
    'high': 'High',
    'normal': 'Normal',
    'low': 'Low',
  };

  // Payment statuses
  static const Map<String, String> paymentStatuses = {
    'pending': 'Pending',
    'paid': 'Paid',
    'late': 'Late',
  };

  // Maintenance statuses
  static const Map<String, String> maintenanceStatuses = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  // Unit statuses
  static const Map<String, String> unitStatuses = {
    'occupied': 'Occupied',
    'vacant': 'Vacant',
    'maintenance': 'Maintenance',
  };

  // Timeline post types
  static const Map<String, String> postTypes = {
    'text': 'Text',
    'photo': 'Photo',
    'poll': 'Poll',
    'event': 'Event',
    'alert': 'Alert',
  };

  // Visibility options
  static const Map<String, String> visibility = {
    'building': 'Building Only',
    'neighborhood': 'Neighborhood',
    'public': 'Public',
  };

  // Expense categories
  static const List<String> expenseCategories = [
    'Elevator',
    'Cleaning',
    'Security',
    'Water',
    'Electricity',
    'Gas',
    'Insurance',
    'Repairs',
    'Garden',
    'Pool',
    'Other',
  ];
}
