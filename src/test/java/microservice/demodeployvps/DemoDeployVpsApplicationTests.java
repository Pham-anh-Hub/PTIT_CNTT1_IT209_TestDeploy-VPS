package microservice.demodeployvps;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
@Disabled("Bỏ qua test kết nối DB khi chạy môi trường local/CI không có MySQL")
class DemoDeployVpsApplicationTests {

    @Test
    void contextLoads() {
    }

}
