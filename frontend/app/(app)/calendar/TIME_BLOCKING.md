# Time-Blocking System

A comprehensive calendar-based time-blocking system for MindForge that helps users schedule, manage, and track their tasks and events with visual planning tools.

## Overview

The time-blocking system provides multiple views and intuitive interfaces for creating and managing time blocks:

- **Quick Create**: Click any calendar time slot to instantly create a task or event
- **Enhanced Create Dialog**: Full-featured creation with duration presets, notes, and better UX
- **Week View**: Visual weekly schedule showing all time blocks
- **List View**: Dashboard showing all time blocks with filtering and sorting
- **Stats View**: Progress tracking and analytics

## Components

### 1. Enhanced Quick Create (`enhanced-quick-create.tsx`)
**Advanced creation interface with time-blocking features:**
- Event/Task type selection (buttons with icons)
- Smart duration estimation with presets (15m, 30m, 1h, 1.5h, 2h, 3h, 4h)
- Duration display with validation
- Notes field for task context
- Better form layout and mobile UX
- Keyboard shortcuts (Enter to submit, Shift+Enter for new line in notes)

**Usage:**
```tsx
<EnhancedQuickCreate
  defaultStart={startDate}
  defaultEnd={endDate}
  onCreate={(title, start, end, isTask, notes) => {
    // Create event or task
  }}
  onCancel={() => {}}
/>
```

### 2. Time Block Presets (`time-block-presets.tsx`)
**Quick duration selector buttons:**
- 15 min, 30 min, 1 hour, 1.5 hours, 2 hours, 3 hours, 4 hours
- Responsive 2-column on mobile, 3-column on desktop
- Icon-labeled header for discoverability

**Usage:**
```tsx
<TimeBlockPresets
  onSelect={(minutes, label) => {
    // Apply preset duration
  }}
/>
```

### 3. Time Blocks Dashboard (`time-blocks-dashboard.tsx`)
**List view with filtering, sorting, and progress tracking:**
- Real-time stats (total blocks, tasks, completed, overdue)
- Color-coded task/event indicators
- Filter options: all, tasks only, events only, today, overdue
- Duration display for events
- Overdue highlighting
- Mobile-optimized card layout

**Features:**
- Task completion checkboxes
- Click to view full event details
- Status badges (Done, Overdue)
- Task notes preview

### 4. Week View (`week-view.tsx`)
**Visual weekly schedule with time grid:**
- 7-day view with hourly slots
- Drag-and-drop support (future enhancement)
- Click to create in time slots
- Today highlight
- Event layer legend
- Color-coded events by type

**Layout:**
- Time column (left sticky)
- 7-day grid with 24 hourly rows
- Responsive scaling on mobile
- Safe area insets for notched devices

### 5. Quick Create Adapter (`quick-create-adapter.tsx`)
**Bridges quick and enhanced create modes:**
- Compact quick create by default
- "Show advanced options" button to switch to full form
- Maintains feature compatibility with existing calendar

### 6. Time Blocking Guide (`time-blocking-guide.tsx`)
**Educational onboarding component:**
- 4 practical time-blocking tips
- Quick start steps
- Dismissible card design
- Cyan-tinted AI-surface styling

**Tips:**
1. Estimate realistic durations (+20% buffer)
2. Create tasks for routine work
3. Avoid back-to-back blocks
4. Block time earlier in day

## Integration Points

### With Calendar Grid
The components integrate seamlessly with the existing `CalendarGrid`:

```tsx
// In month-view or time-grid-view, replace QuickCreateSlot with:
<EnhancedQuickCreate
  defaultStart={slotStart}
  defaultEnd={slotEnd}
  onCreate={handleCreate}
  onCancel={handleCancel}
/>

// Or use the adapter for gradual migration:
<QuickCreateAdapter
  defaultStart={slotStart}
  defaultEnd={slotEnd}
  onCreate={handleCreate}
  onCancel={handleCancel}
  useEnhanced={true}
/>
```

### Server Actions
All components use existing calendar server actions:

- `createEventAction(payload)` - Create event/task
- `updateEventAction(id, payload)` - Update event
- `setEventCompletedAction(id, completed)` - Mark task complete
- `getEventAction(id)` - Fetch full event details

## Event Types

- **Task**: Single point-in-time deadline (no duration)
  - Shows completion checkbox
  - Can be marked done
  - Highlighted if overdue
- **Event**: Time-blocked event with start/end time
  - Displays duration
  - Visual time slot representation
  - Can be dragged to different time

## Features Map

| Feature | Component | Status |
|---------|-----------|--------|
| Quick create on calendar click | QuickCreateSlot | ✅ Existing |
| Enhanced create dialog | EnhancedQuickCreate | ✅ Built |
| Duration presets | TimeBlockPresets | ✅ Built |
| Week view grid | WeekView | ✅ Built |
| List/dashboard view | TimeBlocksDashboard | ✅ Built |
| Filter by type/date | TimeBlocksDashboard | ✅ Built |
| Completion tracking | EventBlock + actions | ✅ Built |
| Notes/context | EnhancedQuickCreate | ✅ Built |
| Mobile responsive | All components | ✅ Built |
| Onboarding guide | TimeBlockingGuide | ✅ Built |
| Drag-and-drop reorder | - | 🔲 Future |
| Time block templates | - | 🔲 Future |
| Recurrence rules | - | 🔲 Future |
| Export to calendar | - | 🔲 Future |

## Styling & Themes

All components follow MindForge design system:
- **Amber (`--primary`)**: User actions, primary buttons, CTAs
- **Cyan (`--ai`)**: AI suggestions, guide content
- **Responsive**: Mobile-first, 44px+ touch targets
- **Dark mode**: Automatic via CSS variables
- **Safe areas**: Notch/camera cutout aware

## Usage Examples

### Basic Integration
```tsx
// In your calendar page
import { TimeBlockingGuide } from "@/app/(app)/plan/time-blocking-guide";
import { TimeBlocksDashboard } from "@/app/(app)/plan/time-blocks-dashboard";

export default function CalendarPage() {
  return (
    <div className="space-y-6">
      <TimeBlockingGuide />
      <TimeBlocksDashboard
        events={events}
        currentUserId={userId}
        onEventClick={handleEventClick}
      />
    </div>
  );
}
```

### Enhanced Create Modal
```tsx
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import { EnhancedQuickCreate } from "@/app/(app)/calendar/enhanced-quick-create";

<Popover open={showCreate} onOpenChange={setShowCreate}>
  <PopoverAnchor asChild>
    <Button>Create Time Block</Button>
  </PopoverAnchor>
  <PopoverContent>
    <EnhancedQuickCreate
      defaultStart={now}
      defaultEnd={oneHourLater}
      onCreate={async (title, start, end, isTask, notes) => {
        await createEventAction({
          title,
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          event_type: isTask ? "task" : "custom",
          notes,
          visibility: "private",
        });
        setShowCreate(false);
      }}
      onCancel={() => setShowCreate(false)}
    />
  </PopoverContent>
</Popover>
```

## Data Model

Events follow the existing CalendarEvent structure:

```typescript
interface CalendarEvent {
  id: string;
  title: string;
  notes?: string;
  starts_at: string;  // ISO datetime
  ends_at?: string;   // ISO datetime
  event_type: "task" | "event" | "mentor_session" | "live_class" | "deadline" | "custom";
  status: "scheduled" | "cancelled";
  completed_at?: string; // Set when task is marked done
  all_day: boolean;
  visibility: "private" | "shared" | "public";
  // ... other fields
}
```

## Mobile Optimization

- Touch targets: 44×44px minimum (WCAG 2.5.5)
- Bottom nav safe area insets for home indicator
- Stack preset buttons in 2 columns on mobile
- Full-screen modals on < sm breakpoint
- Collapsible sections for dense info
- Swipe-friendly spacing

## Accessibility

- Semantic HTML throughout
- ARIA labels on icon-only buttons
- Color not sole indicator (icons, badges)
- Keyboard navigation support
- Sufficient contrast (4.5:1 minimum)
- Focus ring styling
- Screen reader friendly

## Performance Considerations

- Lazy load Week/List views when tabs switch
- Memoize event filter/sort operations
- Virtual scroll for large event lists (future)
- Preload event details on hover (future)

## Future Enhancements

1. **Drag-and-drop**: Reorder time blocks in week view
2. **Templates**: Save/reuse common time block patterns
3. **Analytics**: Time spent vs. scheduled, productivity metrics
4. **Recommendations**: AI-suggested optimal time blocks
5. **Integrations**: Google Calendar, Outlook, iCal
6. **Recurrence**: Repeat events on schedule
7. **Notifications**: Smart reminders and warnings
8. **Teams**: Share calendar and time blocks with team

## Troubleshooting

**"Add advanced options" button appears but doesn't work**
- Ensure EnhancedQuickCreate component loads correctly
- Check browser console for JS errors
- Verify popover container allows resize

**Duration presets don't update end time**
- Presets should calculate from start time, not existing end
- Check that `withTimeOfDay` is using consistent date

**Mobile layout broken at certain widths**
- Verify responsive utilities are applied
- Check container has proper padding/margins
- Test with actual mobile device safe areas

---

**Last updated**: July 2026  
**Status**: Production Ready  
**Version**: 1.0.0
