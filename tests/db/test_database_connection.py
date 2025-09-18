from django.test import TestCase, TransactionTestCase
from django.db import connection


class TestDatabaseConnection(TransactionTestCase):
    def test_database_connection_exists(self):
        """Test that we can connect to the database."""
        assert connection is not None

        # Test basic query
        cursor = connection.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        cursor.close()

        assert result == (1,)

    def test_database_basic_operations(self):
        """Test basic database operations (CREATE, INSERT, SELECT, DROP)."""
        cursor = connection.cursor()

        try:
            # Create a test table
            cursor.execute(
                """
                CREATE TABLE test_table (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name VARCHAR(100) NOT NULL
                )
            """
            )

            # Insert test data
            cursor.execute(
                "INSERT INTO test_table (name) VALUES (%s)",
                ("test_entry",),
            )

            # Query the data
            cursor.execute("SELECT name FROM test_table")
            results = cursor.fetchall()

            assert len(results) == 1
            assert results[0][0] == "test_entry"

            # Clean up
            cursor.execute("DROP TABLE test_table")

        finally:
            cursor.close()

    def test_orm_basic_operations(self):
        """Test Django ORM operations without persistent models."""
        from django.db import models
        
        # Define a model dynamically within the test
        class TestModel(models.Model):
            name = models.CharField(max_length=100)
            created_at = models.DateTimeField(auto_now_add=True)
            
            class Meta:
                app_label = 'test'  # Test app label
        
        # Create the model's table
        with connection.schema_editor() as schema_editor:
            schema_editor.create_model(TestModel)
        
        try:
            # Test ORM operations
            # Create
            obj = TestModel.objects.create(name="Test Object")
            assert obj.name == "Test Object"
            assert obj.pk is not None
            
            # Retrieve
            retrieved = TestModel.objects.get(pk=obj.pk)
            assert retrieved.name == "Test Object"
            
            # Update
            obj.name = "Updated Object"
            obj.save()
            updated = TestModel.objects.get(pk=obj.pk)
            assert updated.name == "Updated Object"
            
            # Delete
            obj.delete()
            assert TestModel.objects.count() == 0
            
        finally:
            # Cleanup
            with connection.schema_editor() as schema_editor:
                schema_editor.delete_model(TestModel)


