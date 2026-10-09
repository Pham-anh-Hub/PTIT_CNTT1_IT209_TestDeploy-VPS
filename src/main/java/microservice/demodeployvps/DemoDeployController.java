package microservice.demodeployvps;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/app")
public class DemoDeployController {
    @GetMapping
    public List<String> getAllString(){
        return List.of("String 1", "String 02", "String 03");
    }
}
