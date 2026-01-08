@isTest
public class AARevenueUtilsTest {
    @isTest static void testGetDoubleRevenue() {
        Decimal result = AARevenueUtils.getDoubleRevenue(100);
        System.assertEquals(200, result);
    }
}