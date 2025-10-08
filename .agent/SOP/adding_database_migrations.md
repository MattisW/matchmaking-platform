# SOP: Adding Database Migrations

**Last Updated:** 2025-10-08
**Related Docs:** [Database Schema](../System/database_schema.md), [Project Architecture](../System/project_architecture.md)

---

## Purpose

This Standard Operating Procedure (SOP) provides step-by-step guidance for creating and managing database migrations in the Matchmaking Platform. Following these guidelines ensures schema changes are safe, reversible, and consistent with project conventions.

---

## When to Create a Migration

Create a migration when you need to:

- ✅ Add new models (tables)
- ✅ Add columns to existing tables
- ✅ Remove columns from tables
- ✅ Change column types or constraints
- ✅ Add or remove indexes
- ✅ Add or remove foreign keys
- ✅ Rename tables or columns
- ✅ Perform data migrations (backfill, cleanup)

**DO NOT create migrations for:**
- ❌ Changing validations (handle in model only)
- ❌ Adding methods to models
- ❌ Changing application logic
- ❌ Configuration changes

---

## Project-Specific Context

### SQLite Database

This project uses **SQLite in production** (Rails 8 feature). Key implications:

1. **No native array types** - Use serialized JSON in TEXT columns
2. **Limited column type changes** - Some operations require table recreation
3. **Foreign key constraints** - Enabled by default in Rails 8
4. **Single-file database** - All schema changes affect one `.sqlite3` file

### Rails Version

- **Rails 8.0+** with ActiveRecord 8.0
- Migrations inherit from `ActiveRecord::Migration[8.0]`
- Uses reversible `change` method by default

---

## Migration Naming Conventions

Rails migrations use **timestamp-based prefixes** for ordering:

```
YYYYMMDDHHMMSS_descriptive_name.rb
```

### Naming Patterns

**Creating Tables:**
```
rails generate migration CreateTableName field1:type field2:type
# Example: 20251008075752_create_quotes.rb
```

**Adding Columns:**
```
rails generate migration AddFieldToTable field:type
# Example: 20251008072221_add_locale_to_users.rb
```

**Removing Columns:**
```
rails generate migration RemoveFieldFromTable field:type
# Example: 20251010123456_remove_legacy_field_from_carriers.rb
```

**Changing Columns:**
```
rails generate migration ChangeFieldInTable
# Example: 20251005184929_make_matched_carrier_id_nullable.rb
```

**Adding Indexes:**
```
rails generate migration AddIndexToTable
# Example: 20251010123456_add_index_to_carrier_requests.rb
```

**Data Migrations:**
```
rails generate migration BackfillFieldInTable
# Example: 20251010123456_backfill_currency_in_quotes.rb
```

---

## Step-by-Step Guide

### 1. Generate Migration File

Use Rails generator:

```bash
rails generate migration MigrationName
```

**Example:**
```bash
rails generate migration AddCompanyNameToUsers company_name:string
```

This creates:
```
db/migrate/20251008123456_add_company_name_to_users.rb
```

---

### 2. Edit Migration File

Open the generated file and implement the schema change.

**Template:**
```ruby
class MigrationName < ActiveRecord::Migration[8.0]
  def change
    # Schema changes here
  end
end
```

---

### 3. Common Migration Patterns

#### Pattern 1: Adding Columns

**Use Case:** Add new fields to existing table

**Example:**
```ruby
class AddLocaleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :locale, :string, default: 'de', null: false
  end
end
```

**Options:**
- `default:` - Default value for new rows
- `null:` - Allow NULL values (default: `true`)
- `limit:` - Max length for strings
- `precision:`, `scale:` - For decimal fields

**Column Types:**
- `:string` - VARCHAR (max 255 chars)
- `:text` - TEXT (unlimited length)
- `:integer` - INTEGER
- `:decimal` - DECIMAL (for currency, use `precision: 10, scale: 2`)
- `:boolean` - BOOLEAN
- `:datetime` - DATETIME
- `:date` - DATE
- `:json` - JSON (SQLite stores as TEXT)

---

#### Pattern 2: Adding Multiple Related Columns

**Use Case:** Add a group of related fields (e.g., address components)

**Example:**
```ruby
class AddDetailedAddressFieldsToTransportRequests < ActiveRecord::Migration[8.0]
  def change
    # Pickup Address Fields
    add_column :transport_requests, :start_company_name, :string
    add_column :transport_requests, :start_street, :string
    add_column :transport_requests, :start_street_number, :string
    add_column :transport_requests, :start_city, :string
    add_column :transport_requests, :start_postal_code, :string
    add_column :transport_requests, :start_notes, :text

    # Delivery Address Fields
    add_column :transport_requests, :destination_company_name, :string
    add_column :transport_requests, :destination_street, :string
    add_column :transport_requests, :destination_street_number, :string
    add_column :transport_requests, :destination_city, :string
    add_column :transport_requests, :destination_postal_code, :string
    add_column :transport_requests, :destination_notes, :text
  end
end
```

**Best Practice:** Group related fields with comments for clarity.

---

#### Pattern 3: Creating New Tables

**Use Case:** Add a new model with associations

**Example:**
```ruby
class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      # Foreign key (belongs_to)
      t.references :transport_request, null: false, foreign_key: true

      # Regular fields
      t.string :status, default: 'pending', null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.decimal :base_price, precision: 10, scale: 2, null: false
      t.decimal :surcharge_total, precision: 10, scale: 2, default: 0.0
      t.string :currency, default: 'EUR', null: false

      # Optional fields
      t.datetime :valid_until
      t.datetime :accepted_at
      t.datetime :declined_at
      t.text :notes

      # Timestamps (created_at, updated_at)
      t.timestamps
    end

    # Add indexes for frequently queried columns
    add_index :quotes, :status
  end
end
```

**Key Points:**
- **Always include `t.timestamps`** for `created_at` and `updated_at`
- Use `t.references` for foreign keys (automatically adds `_id` column and index)
- Add `foreign_key: true` for referential integrity
- Add indexes for columns used in `WHERE` clauses or `ORDER BY`

---

#### Pattern 4: Serialized Arrays (SQLite)

**Use Case:** Store array of values (e.g., country codes, tags)

**Migration:**
```ruby
class AddCountryArraysToCarriers < ActiveRecord::Migration[8.0]
  def change
    add_column :carriers, :pickup_countries, :text
    add_column :carriers, :delivery_countries, :text
  end
end
```

**Model Configuration:**
```ruby
class Carrier < ApplicationRecord
  serialize :pickup_countries, coder: JSON, type: Array
  serialize :delivery_countries, coder: JSON, type: Array
end
```

**Usage:**
```ruby
carrier.pickup_countries = ['DE', 'AT', 'CH']
carrier.save!

carrier.pickup_countries
# => ["DE", "AT", "CH"]
```

**Why TEXT, not JSON?**
- SQLite stores JSON as TEXT internally
- ActiveRecord's `serialize` handles JSON encoding/decoding
- Querying arrays in SQLite requires LIKE or JSON functions (not efficient)

---

#### Pattern 5: Changing Column Properties

**Use Case:** Make a column nullable, change default, or change type

**Making Column Nullable:**
```ruby
class MakeMatchedCarrierIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :transport_requests, :matched_carrier_id, true
  end
end
```

**Changing Default Value:**
```ruby
class ChangeDefaultStatusInQuotes < ActiveRecord::Migration[8.0]
  def change
    change_column_default :quotes, :status, from: 'pending', to: 'draft'
  end
end
```

**Changing Column Type:**
```ruby
class ChangePriceToDecimalInQuotes < ActiveRecord::Migration[8.0]
  def change
    # SQLite limitation: requires up/down instead of change
    reversible do |dir|
      dir.up do
        change_column :quotes, :total_price, :decimal, precision: 10, scale: 2
      end
      dir.down do
        change_column :quotes, :total_price, :integer
      end
    end
  end
end
```

**⚠️ SQLite Limitation:** Changing column type may require table recreation in some cases.

---

#### Pattern 6: Adding Indexes

**Use Case:** Speed up queries on frequently filtered/sorted columns

**Example:**
```ruby
class AddIndexesToCarrierRequests < ActiveRecord::Migration[8.0]
  def change
    add_index :carrier_requests, :status
    add_index :carrier_requests, :email_sent_at
    add_index :carrier_requests, [:transport_request_id, :carrier_id], unique: true
  end
end
```

**When to Add Indexes:**
- ✅ Foreign keys (automatic with `t.references`)
- ✅ Columns used in `WHERE` clauses
- ✅ Columns used in `ORDER BY`
- ✅ Columns used in `JOIN` conditions
- ✅ Status/enum fields
- ✅ Timestamp fields used for filtering

**Composite Index:**
Use for queries filtering on multiple columns together:
```ruby
add_index :carrier_requests, [:transport_request_id, :status]
```

**Unique Index:**
Enforce uniqueness at database level:
```ruby
add_index :carrier_requests, [:transport_request_id, :carrier_id], unique: true
```

---

#### Pattern 7: Removing Columns

**Use Case:** Remove deprecated or unused fields

**Example:**
```ruby
class RemoveLegacyFieldsFromCarriers < ActiveRecord::Migration[8.0]
  def change
    remove_column :carriers, :old_rating, :integer
    remove_column :carriers, :deprecated_field, :string
  end
end
```

**⚠️ WARNING:** Removing columns is **destructive and irreversible**. Data is permanently deleted.

**Safe Removal Process:**
1. Deploy code that stops using the column
2. Wait 1-2 weeks to ensure no issues
3. Create migration to remove column
4. Deploy migration

---

#### Pattern 8: Data Migrations

**Use Case:** Backfill data, clean up invalid records, or transform existing data

**Example:**
```ruby
class BackfillCurrencyInQuotes < ActiveRecord::Migration[8.0]
  def up
    # Backfill missing currency with default
    Quote.where(currency: nil).update_all(currency: 'EUR')
  end

  def down
    # Reversal: set currency back to nil (destructive)
    Quote.where(currency: 'EUR').update_all(currency: nil)
  end
end
```

**Best Practices:**
- Use `up` and `down` methods (not `change`) for clarity
- Use `update_all` for bulk updates (skips validations and callbacks)
- Consider performance for large tables (use batching)
- Add logging for visibility

**Batching for Large Tables:**
```ruby
class BackfillCurrencyInQuotes < ActiveRecord::Migration[8.0]
  def up
    Quote.where(currency: nil).in_batches(of: 1000) do |batch|
      batch.update_all(currency: 'EUR')
      print "."  # Progress indicator
    end
    puts " Done!"
  end

  def down
    # Reversal logic
  end
end
```

---

### 4. Testing Migrations

**Always test migrations before committing.**

#### Step 1: Run Migration

```bash
rails db:migrate
```

**Expected Output:**
```
== 20251008123456 AddCompanyNameToUsers: migrating ===========================
-- add_column(:users, :company_name, :string)
   -> 0.0012s
== 20251008123456 AddCompanyNameToUsers: migrated (0.0013s) ==================
```

#### Step 2: Verify Schema

Check `db/schema.rb` to ensure changes are correct:

```bash
git diff db/schema.rb
```

**Example Diff:**
```diff
+    t.string "company_name"
```

#### Step 3: Test Rollback

**CRITICAL:** Ensure migration is reversible:

```bash
rails db:rollback
```

**Expected Output:**
```
== 20251008123456 AddCompanyNameToUsers: reverting ===========================
-- remove_column(:users, :company_name, :string)
   -> 0.0008s
== 20251008123456 AddCompanyNameToUsers: reverted (0.0009s) ==================
```

#### Step 4: Re-run Migration

```bash
rails db:migrate
```

Should succeed without errors.

#### Step 5: Test in Rails Console

```bash
rails console
```

```ruby
# Test adding data to new column
user = User.first
user.update(company_name: 'Test Company')
user.company_name
# => "Test Company"
```

---

### 5. Commit Migration

**Git Workflow:**

```bash
# Check status
git status

# Add migration and schema
git add db/migrate/20251008123456_add_company_name_to_users.rb
git add db/schema.rb

# Commit with descriptive message
git commit -m "Add company_name to users

- Add company_name string column to users table
- Allow users to specify their company name during registration
- Supports customer portal company identification"
```

**Commit Message Format:**
```
Brief summary (50 chars or less)

- Detailed explanation of changes
- Rationale for the change
- Impact on existing data (if any)
- Related ticket/issue number (if applicable)
```

---

## SQLite-Specific Considerations

### 1. No Native Array Type

**Problem:** SQLite doesn't support `array` column type

**Solution:** Use TEXT column + JSON serialization

```ruby
# Migration
add_column :carriers, :pickup_countries, :text

# Model
serialize :pickup_countries, coder: JSON, type: Array
```

**Storage Format:**
```sql
SELECT pickup_countries FROM carriers WHERE id = 1;
-- Result: '["DE", "AT", "CH"]'
```

---

### 2. Limited ALTER TABLE Support

**Problem:** SQLite has limited `ALTER TABLE` capabilities

**Workarounds:**

**Can't Change Column Type Directly:**
```ruby
# Instead of:
change_column :quotes, :price, :decimal  # May fail

# Do this:
def up
  add_column :quotes, :price_new, :decimal, precision: 10, scale: 2
  Quote.update_all('price_new = price')
  remove_column :quotes, :price
  rename_column :quotes, :price_new, :price
end
```

**Can't Rename Columns Directly (older SQLite):**
```ruby
# Use up/down methods for clarity
def up
  add_column :quotes, :new_name, :string
  Quote.update_all('new_name = old_name')
  remove_column :quotes, :old_name
end

def down
  add_column :quotes, :old_name, :string
  Quote.update_all('old_name = new_name')
  remove_column :quotes, :new_name
end
```

---

### 3. Foreign Key Constraints

**Enabled by Default in Rails 8:**

```ruby
t.references :transport_request, null: false, foreign_key: true
```

**Generates:**
```sql
FOREIGN KEY (transport_request_id) REFERENCES transport_requests(id)
```

**Implications:**
- Cannot delete parent if children exist (must use `dependent: :destroy`)
- Referential integrity enforced at database level
- Safer than application-level validation only

---

### 4. Index Limitations

**No Partial Indexes in SQLite < 3.8.0:**
```ruby
# This may fail on older SQLite:
add_index :quotes, :status, where: "status = 'active'"

# Use full index instead:
add_index :quotes, :status
```

---

## Common Patterns Reference

### Adding Foreign Key

```ruby
add_reference :carrier_requests, :transport_request, foreign_key: true, index: true
```

Generates:
- `carrier_requests.transport_request_id` (integer)
- Index on `transport_request_id`
- Foreign key constraint

---

### Adding Composite Index

```ruby
add_index :carrier_requests, [:transport_request_id, :carrier_id], unique: true
```

Use when querying on both columns together.

---

### Adding Status Field (Enum-like)

```ruby
add_column :carrier_requests, :status, :string, default: 'new', null: false
add_index :carrier_requests, :status
```

Model:
```ruby
validates :status, inclusion: { in: %w[new sent offered won rejected] }
```

---

### Adding Timestamp Field

```ruby
add_column :carrier_requests, :email_sent_at, :datetime
add_index :carrier_requests, :email_sent_at
```

---

### Adding Decimal Currency Field

```ruby
add_column :quotes, :total_price, :decimal, precision: 10, scale: 2, null: false
```

- `precision: 10` - Total digits (e.g., 12345678.90 = 10 digits)
- `scale: 2` - Digits after decimal (e.g., .90 = 2 digits)

---

## Rollback Safety

### Safe (Reversible) Migrations

These migrations are automatically reversible with `rails db:rollback`:

✅ `add_column`
✅ `add_index`
✅ `add_reference`
✅ `create_table`
✅ `create_join_table`
✅ `remove_timestamps`
✅ `rename_column`
✅ `rename_index`
✅ `rename_table`

---

### Unsafe (Irreversible) Migrations

These require explicit `up` and `down` methods:

⚠️ `change_column`
⚠️ `change_column_default`
⚠️ `remove_column`
⚠️ `execute` (raw SQL)

**Example:**
```ruby
def up
  change_column :users, :role, :string, default: 'customer', null: false
end

def down
  change_column :users, :role, :string, default: 'admin', null: true
end
```

---

### Data Migration Reversals

**Guideline:** Data migrations should have meaningful rollback logic or be marked irreversible.

**Reversible Data Migration:**
```ruby
def up
  User.where(role: nil).update_all(role: 'customer')
end

def down
  # Reversal: Set role back to nil (data loss!)
  User.where(role: 'customer').update_all(role: nil)
end
```

**Irreversible Data Migration:**
```ruby
def up
  # Destructive operation
  Quote.where('created_at < ?', 1.year.ago).delete_all
end

def down
  raise ActiveRecord::IrreversibleMigration
end
```

---

## Troubleshooting

### Error: "PG::UndefinedColumn: column does not exist"

**Cause:** Migration not run in environment

**Solution:**
```bash
rails db:migrate
```

---

### Error: "SQLite3::SQLException: no such table"

**Cause:** Database not created

**Solution:**
```bash
rails db:create
rails db:migrate
```

---

### Error: "StandardError: An error has occurred, this and all later migrations canceled"

**Cause:** Syntax error or invalid operation in migration

**Solution:**
1. Fix the migration file
2. If migration partially applied:
   ```bash
   rails db:rollback  # Undo partial changes
   rails db:migrate   # Re-run corrected migration
   ```

---

### Error: "ActiveRecord::IrreversibleMigration"

**Cause:** Attempting to rollback a migration without `down` method

**Solution:** Add explicit `down` method or use `reversible` block

---

### Migration Stuck at "migrating..."

**Cause:** Long-running data migration or database lock

**Solution:**
1. Check database locks:
   ```bash
   rails dbconsole
   PRAGMA database_list;
   ```
2. Add progress logging to migration:
   ```ruby
   def up
     Quote.in_batches(of: 1000).each_with_index do |batch, index|
       batch.update_all(currency: 'EUR')
       puts "Processed batch #{index + 1}..."
     end
   end
   ```

---

## Best Practices Summary

### ✅ DO:
- ✅ Use descriptive migration names
- ✅ Test rollback before committing
- ✅ Add indexes for foreign keys and frequently queried columns
- ✅ Use `null: false` for required fields
- ✅ Set sensible `default:` values
- ✅ Always include `t.timestamps` in new tables
- ✅ Use `t.references` for associations (adds foreign key + index)
- ✅ Add comments for complex migrations
- ✅ Review `db/schema.rb` diff after migration
- ✅ Commit migration and schema together
- ✅ Use `up`/`down` for data migrations

### ❌ DON'T:
- ❌ Edit existing migrations after they've been run in production
- ❌ Remove columns without testing in development first
- ❌ Use `execute` with raw SQL unless absolutely necessary
- ❌ Forget to test rollback
- ❌ Skip adding indexes on foreign keys
- ❌ Use `change_column` without understanding SQLite limitations
- ❌ Commit broken migrations
- ❌ Change `db/schema.rb` manually (always generate via migrations)

---

## Migration Checklist

Before deploying a migration to production:

- [ ] Migration runs successfully in development: `rails db:migrate`
- [ ] Migration rolls back cleanly: `rails db:rollback`
- [ ] Schema diff looks correct: `git diff db/schema.rb`
- [ ] Tested adding/updating data with new columns in `rails console`
- [ ] Migration has descriptive name
- [ ] Added indexes for foreign keys and frequently queried columns
- [ ] Set appropriate `null: false` and `default:` values
- [ ] Data migration includes progress logging (if long-running)
- [ ] Rollback logic is safe or migration marked irreversible
- [ ] Commit message explains purpose of migration

---

## Related Documentation

- **[Database Schema Reference](../System/database_schema.md)** - Current database structure
- **[Project Architecture](../System/project_architecture.md)** - SQLite decision rationale
- **Rails Guides:** [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- **SQLite Documentation:** [ALTER TABLE](https://www.sqlite.org/lang_altertable.html)

---

## Version History

| Date | Change | Author |
|------|--------|--------|
| 2025-10-08 | Initial SOP created | Claude Code |

---

**Last Review:** 2025-10-08
**Next Review Due:** 2025-11-08
