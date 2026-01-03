@isTest
private class AACalculatorTest {
    @isTest
    static void testAdd() {
        // Test the add method
        Integer result = AACalculator.add(5, 10);
        
        // Validate the result
        System.assertEquals(15, result, 'The addition result should be 15');
    }
}