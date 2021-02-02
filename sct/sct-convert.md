## 오브젝트 변환하기 ##

### 리포트 출력하기 ###

오라클의 오브젝트를 postgresql 로 변환하기 전에 리포트를 뽑아서 발생가능 한 오류에 대해 확인할 수 있다.  
데이터성 오브젝트 보다는 코드성 오브 젝트에서 대부분의 오류가 발생하고, 오류를 확인해서 수동으로 조정해 줘야 한다. 

[summary]
![create report](https://github.com/gnosia93/postgres-terraform/blob/main/sct/images/sct-report.png)

수정 또는 확인이 필요한 액션 아이템을 보여준고 있다. 주로 프로시저나 함수, 트리거와 같은 코드성 오브젝트에서 발생한다. 

[action item]
![action item](https://github.com/gnosia93/postgres-terraform/blob/main/sct/images/sct-action-item.png)