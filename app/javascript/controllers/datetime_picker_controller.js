import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "pickupCollapsed", "pickupExpanded", "pickupCalendar", "pickupTimeGrid",
    "deliveryCollapsed", "deliveryExpanded", "deliveryCalendar", "deliveryTimeGrid",
    "pickupDateInput", "pickupTimeInput",
    "deliveryDateInput", "deliveryTimeInput",
    "validationError", "successSummary"
  ]

  static values = {
    pickupDate: String,
    pickupTime: String,
    deliveryDate: String,
    deliveryTime: String,
    pickupExpanded: { type: Boolean, default: false },
    deliveryExpanded: { type: Boolean, default: false },
    pickupShowAllTimes: { type: Boolean, default: false },
    deliveryShowAllTimes: { type: Boolean, default: false },
    pickupMonth: Number,
    pickupYear: Number,
    deliveryMonth: Number,
    deliveryYear: Number
  }

  connect() {
    // Initialize with current values from form
    this.pickupDateValue = this.pickupDateInputTarget.value || ''
    this.pickupTimeValue = this.pickupTimeInputTarget.value || ''
    this.deliveryDateValue = this.deliveryDateInputTarget.value || ''
    this.deliveryTimeValue = this.deliveryTimeInputTarget.value || ''

    // Initialize calendar months
    const today = new Date()
    this.pickupMonthValue = today.getMonth()
    this.pickupYearValue = today.getFullYear()
    this.deliveryMonthValue = today.getMonth()
    this.deliveryYearValue = today.getFullYear()

    // Disable delivery section if pickup not selected
    this.updateDeliveryState()

    this.updateAllDisplays()
  }

  updateDeliveryState() {
    const hasPickup = this.pickupDateValue && this.pickupTimeValue

    if (!hasPickup) {
      // Disable delivery section
      this.deliveryCollapsedTarget.classList.add('opacity-50', 'cursor-not-allowed')
      this.deliveryCollapsedTarget.disabled = true
    } else {
      // Enable delivery section
      this.deliveryCollapsedTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      this.deliveryCollapsedTarget.disabled = false
    }
  }

  toggleExpanded(event) {
    const field = event.currentTarget.dataset.field

    // Don't allow delivery to expand if pickup not selected
    if (field === 'delivery' && (!this.pickupDateValue || !this.pickupTimeValue)) {
      return
    }

    if (field === 'pickup') {
      this.pickupExpandedValue = !this.pickupExpandedValue
      if (this.pickupExpandedValue) {
        this.renderPickupCalendar()
        if (this.pickupDateValue) {
          this.renderPickupTimeGrid()
        }
      }
    } else {
      this.deliveryExpandedValue = !this.deliveryExpandedValue
      if (this.deliveryExpandedValue) {
        this.renderDeliveryCalendar()
        if (this.deliveryDateValue) {
          this.renderDeliveryTimeGrid()
        }
      }
    }

    this.updateExpandedStates()
  }

  pickupExpandedValueChanged() {
    this.updateExpandedStates()
  }

  deliveryExpandedValueChanged() {
    this.updateExpandedStates()
  }

  updateExpandedStates() {
    // Pickup
    if (this.pickupExpandedValue) {
      this.pickupExpandedTarget.classList.remove('hidden')
      this.pickupCollapsedTarget.classList.add('bg-green-50')
    } else {
      this.pickupExpandedTarget.classList.add('hidden')
      this.pickupCollapsedTarget.classList.remove('bg-green-50')
    }

    // Delivery
    if (this.hasDeliveryExpandedTarget) {
      if (this.deliveryExpandedValue) {
        this.deliveryExpandedTarget.classList.remove('hidden')
        this.deliveryCollapsedTarget.classList.add('bg-blue-50')
      } else {
        this.deliveryExpandedTarget.classList.add('hidden')
        this.deliveryCollapsedTarget.classList.remove('bg-blue-50')
      }
    }
  }

  renderPickupCalendar() {
    this.renderCalendar('pickup', this.pickupMonthValue, this.pickupYearValue)
  }

  renderDeliveryCalendar() {
    this.renderCalendar('delivery', this.deliveryMonthValue, this.deliveryYearValue)
  }

  renderCalendar(field, month, year) {
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December']

    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const daysInMonth = lastDay.getDate()
    const startingDayOfWeek = firstDay.getDay()

    const isPickup = field === 'pickup'

    let html = `
      <div class="bg-white rounded-lg border-2 border-gray-200 p-4">
        <div class="flex items-center justify-between mb-4">
          <button type="button"
                  data-action="datetime-picker#previousMonth"
                  data-field="${field}"
                  class="p-2 hover:bg-gray-100 rounded-lg transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <div class="font-bold text-gray-900">${monthNames[month]} ${year}</div>
          <button type="button"
                  data-action="datetime-picker#nextMonth"
                  data-field="${field}"
                  class="p-2 hover:bg-gray-100 rounded-lg transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <div class="grid grid-cols-7 gap-1 mb-2">
          ${['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map(day =>
            `<div class="text-center text-xs font-semibold text-gray-500 py-2">${day}</div>`
          ).join('')}
        </div>

        <div class="grid grid-cols-7 gap-1">
    `

    // Empty cells before first day
    for (let i = 0; i < startingDayOfWeek; i++) {
      html += '<div class="aspect-square"></div>'
    }

    // Actual days
    for (let day = 1; day <= daysInMonth; day++) {
      const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      const dateObj = new Date(dateStr)
      const isSelected = this[`${field}DateValue`] === dateStr
      const isDisabled = this.isDateDisabled(dateObj, field)
      const isToday = this.isToday(dateObj)

      let buttonClass = 'aspect-square rounded-lg font-medium text-sm transition-all '
      if (isSelected) {
        buttonClass += isPickup
          ? 'bg-green-500 text-white ring-2 ring-green-300 shadow-md'
          : 'bg-blue-500 text-white ring-2 ring-blue-300 shadow-md'
      } else if (isToday) {
        buttonClass += 'border-2 border-gray-900 text-gray-900 hover:bg-gray-100'
      } else if (isDisabled) {
        buttonClass += 'text-gray-300 cursor-not-allowed'
      } else {
        buttonClass += 'text-gray-700 hover:bg-gray-100'
      }

      html += `
        <button type="button"
                data-action="datetime-picker#selectDate"
                data-field="${field}"
                data-date="${dateStr}"
                ${isDisabled ? 'disabled' : ''}
                class="${buttonClass}">
          ${day}
        </button>
      `
    }

    html += '</div></div>'

    this[`${field}CalendarTarget`].innerHTML = html
  }

  renderPickupTimeGrid() {
    this.renderTimeGrid('pickup', this.pickupShowAllTimesValue)
  }

  renderDeliveryTimeGrid() {
    this.renderTimeGrid('delivery', this.deliveryShowAllTimesValue)
  }

  renderTimeGrid(field, showAll = false) {
    const times = this.generateTimeSlots(showAll ? 0 : 6, showAll ? 24 : 19)
    const isPickup = field === 'pickup'
    const bgClass = isPickup ? 'bg-green-50/30' : 'bg-blue-50/30'
    const textColorClass = isPickup ? 'text-green-600 hover:text-green-700' : 'text-blue-600 hover:text-blue-700'

    let html = `
      <div class="p-4 border-t-2 border-gray-200 ${bgClass} space-y-4">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-3">
            Select Time (24h format)
          </label>
          <div class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2">
    `

    times.forEach(time => {
      const isSelected = this[`${field}TimeValue`] === time
      const isDisabled = this.isTimeDisabled(time, field)

      let buttonClass = 'py-2 px-1 rounded-lg font-medium text-sm transition-all '
      if (isSelected) {
        buttonClass += isPickup
          ? 'bg-green-500 text-white ring-2 ring-green-300 shadow-md'
          : 'bg-blue-500 text-white ring-2 ring-blue-300 shadow-md'
      } else if (isDisabled) {
        buttonClass += 'bg-gray-100 text-gray-400 cursor-not-allowed'
      } else {
        buttonClass += 'bg-white border-2 border-gray-200 text-gray-700 hover:border-gray-400 hover:shadow-sm'
      }

      html += `
        <button type="button"
                data-action="datetime-picker#selectTime"
                data-field="${field}"
                data-time="${time}"
                ${isDisabled ? 'disabled' : ''}
                class="${buttonClass}">
          ${time}
        </button>
      `
    })

    html += `
          </div>
          ${!showAll ? `
            <button type="button"
                    data-action="datetime-picker#showAllTimes"
                    data-field="${field}"
                    class="mt-3 text-sm ${textColorClass} font-medium flex items-center gap-1">
              Show all times (00:00 - 23:45)
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          ` : ''}
        </div>
      </div>
    `

    this[`${field}TimeGridTarget`].innerHTML = html
  }

  selectDate(event) {
    const field = event.currentTarget.dataset.field
    const date = event.currentTarget.dataset.date

    this[`${field}DateValue`] = date
    this[`${field}DateInputTarget`].value = date

    // Re-render calendar to show selection
    this[`render${field.charAt(0).toUpperCase() + field.slice(1)}Calendar`]()

    // Show time grid
    this[`render${field.charAt(0).toUpperCase() + field.slice(1)}TimeGrid`]()

    this.validateAndUpdate()
  }

  selectTime(event) {
    const field = event.currentTarget.dataset.field
    const time = event.currentTarget.dataset.time

    this[`${field}TimeValue`] = time
    this[`${field}TimeInputTarget`].value = time

    // Auto-collapse after brief delay
    setTimeout(() => {
      this[`${field}ExpandedValue`] = false

      // Enable delivery section if pickup complete
      if (field === 'pickup' && this.pickupDateValue && this.pickupTimeValue) {
        this.updateDeliveryState()
      }

      this.updateAllDisplays()
    }, 300)

    this.validateAndUpdate()
  }

  previousMonth(event) {
    const field = event.currentTarget.dataset.field
    const monthKey = `${field}Month`
    const yearKey = `${field}Year`

    if (this[`${monthKey}Value`] === 0) {
      this[`${monthKey}Value`] = 11
      this[`${yearKey}Value`]--
    } else {
      this[`${monthKey}Value`]--
    }

    this[`render${field.charAt(0).toUpperCase() + field.slice(1)}Calendar`]()
  }

  nextMonth(event) {
    const field = event.currentTarget.dataset.field
    const monthKey = `${field}Month`
    const yearKey = `${field}Year`

    if (this[`${monthKey}Value`] === 11) {
      this[`${monthKey}Value`] = 0
      this[`${yearKey}Value`]++
    } else {
      this[`${monthKey}Value`]++
    }

    this[`render${field.charAt(0).toUpperCase() + field.slice(1)}Calendar`]()
  }

  showAllTimes(event) {
    const field = event.currentTarget.dataset.field
    this[`${field}ShowAllTimesValue`] = true
    this[`render${field.charAt(0).toUpperCase() + field.slice(1)}TimeGrid`]()
  }

  // Helper methods

  generateTimeSlots(startHour, endHour) {
    const slots = []
    for (let hour = startHour; hour < endHour; hour++) {
      for (let minute = 0; minute < 60; minute += 15) {
        const hourStr = hour.toString().padStart(2, '0')
        const minuteStr = minute.toString().padStart(2, '0')
        slots.push(`${hourStr}:${minuteStr}`)
      }
    }
    return slots
  }

  isToday(date) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const checkDate = new Date(date)
    checkDate.setHours(0, 0, 0, 0)
    return checkDate.getTime() === today.getTime()
  }

  isDateDisabled(date, field) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const checkDate = new Date(date)
    checkDate.setHours(0, 0, 0, 0)

    const maxFuture = new Date(today)
    maxFuture.setDate(maxFuture.getDate() + 30)

    // Past dates always disabled
    if (checkDate < today) return true

    // Beyond 30 days disabled
    if (checkDate > maxFuture) return true

    // For delivery, must be >= pickup date
    if (field === 'delivery' && this.pickupDateValue) {
      const pickupDate = new Date(this.pickupDateValue)
      pickupDate.setHours(0, 0, 0, 0)
      if (checkDate < pickupDate) return true
    }

    return false
  }

  isTimeDisabled(time, field) {
    // Only delivery times can be disabled
    if (field !== 'delivery') return false

    // Only on same day as pickup
    if (!this.pickupDateValue || !this.deliveryDateValue) return false
    if (this.pickupDateValue !== this.deliveryDateValue) return false

    // Delivery time must be after pickup time
    return time <= this.pickupTimeValue
  }

  validateSelection() {
    if (!this.pickupDateValue || !this.pickupTimeValue ||
        !this.deliveryDateValue || !this.deliveryTimeValue) {
      return null // Not complete yet
    }

    const pickup = new Date(`${this.pickupDateValue}T${this.pickupTimeValue}`)
    const delivery = new Date(`${this.deliveryDateValue}T${this.deliveryTimeValue}`)

    if (delivery <= pickup) {
      return 'Delivery must be after pickup'
    }

    return null // Valid
  }

  validateAndUpdate() {
    const error = this.validateSelection()

    if (error) {
      this.validationErrorTarget.innerHTML = `
        <div class="bg-red-50 border-2 border-red-200 rounded-lg p-4 flex items-start gap-3">
          <svg class="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div class="text-sm text-red-700 font-medium">${error}</div>
        </div>
      `
      this.validationErrorTarget.classList.remove('hidden')
      this.successSummaryTarget.classList.add('hidden')
    } else if (this.pickupDateValue && this.pickupTimeValue &&
               this.deliveryDateValue && this.deliveryTimeValue) {
      // Valid and complete
      this.validationErrorTarget.classList.add('hidden')
      this.updateSuccessSummary()
    } else {
      // Incomplete
      this.validationErrorTarget.classList.add('hidden')
      this.successSummaryTarget.classList.add('hidden')
    }

    this.updateAllDisplays()
  }

  updateSuccessSummary() {
    // Don't show the success summary banner - datetime info already visible in collapsed headers
    this.successSummaryTarget.classList.add('hidden')
  }

  formatDisplay(date, time) {
    if (!date || !time) return 'Select date & time'

    const dateObj = new Date(date)
    const dayName = dateObj.toLocaleDateString('en-GB', { weekday: 'short' })
    const dateStr = dateObj.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })

    return `${dayName}, ${dateStr} • ${time}`
  }

  updateAllDisplays() {
    this.updateCollapsedDisplay('pickup')
    if (this.hasDeliveryCollapsedTarget) {
      this.updateCollapsedDisplay('delivery')
    }
  }

  updateCollapsedDisplay(field) {
    const date = this[`${field}DateValue`]
    const time = this[`${field}TimeValue`]
    const hasValue = date && time
    const isPickup = field === 'pickup'

    const collapsedTarget = this[`${field}CollapsedTarget`]

    // Update border
    if (hasValue) {
      collapsedTarget.classList.add('border-l-4')
      if (isPickup) {
        collapsedTarget.classList.add('border-l-green-500')
        collapsedTarget.classList.remove('border-l-blue-500')
      } else {
        collapsedTarget.classList.add('border-l-blue-500')
        collapsedTarget.classList.remove('border-l-green-500')
      }
    } else {
      collapsedTarget.classList.remove('border-l-4', 'border-l-green-500', 'border-l-blue-500')
    }

    // Icons now have fixed colors (green-600/blue-600 with white icons) - no dynamic changes needed

    // Update text
    const textDiv = collapsedTarget.querySelector('.display-text')
    if (textDiv) {
      textDiv.textContent = this.formatDisplay(date, time)
      // Text color is already text-gray-900 by default, no need to change
    }
  }
}
