module addr::todo_list{
    use aptos_framework::account;
    use std::signer;
    use std::error;
    use std::string;
    use aptos_framework::event;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    #[test_only]
    use std::string;

    const ENO_MESSAGE:u64 = 0;
    const E_NOT_INITIALIZED: u64 = 1;
    const ETASK_DOESNT_EXIST: u64 =2;
    const ETASK_IS_COMPLETED: u64 = 3;

    struct Todolist has key{
        tasks: Table<u64,Task>,
        set_task_event: event::EventHandle<Task>,
        task_counter: u64
    }

    struct Task has store, drop, copy{
        task_id: u64,
        address:address,
        content: String,
        completed: bool,
    }

    public entry fun create_list(account: &signer){
        let todo_list = Todolist{
            tasks: table::new(),
            set_task_event: account::new_event_handle<Task>(account),
            task_counter: 0
        };
        move_to(account, todo_list);
    }

    public entry fun create_task(account:&signer, content: String) acquires Todolist{
        let signer_address = signer::address_of(account);
        assert!(exists<Todolist>(signer_address),E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<Todolist>(signer_address);
        let counter = todo_list.task_counter+1;
        let new_task = Task{
            task_id: counter,
            address: signer_address,
            content,
            completed: false
        };

        table::upsert(&mut todo_list.tasks,counter,new_task);

        todo_list.task_counter = counter;

        event::emit_event<Task>(
            &mut borrow_global_mut<Todolist>(signer_address).set_task_event,
            new_task,
        );
    }

    public entry fun complete_task(account:&signer, task_id:u64) acquires Todolist{
        let signer_address = signer::address_of(account);
        assert!(exists<Todolist>(signer_address),E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<Todolist>(signer_address);
        assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        let task_record = table::borrow_mut(&mut todo_list.tasks,task_id);
        assert!(task_record.completed==false,ETASK_IS_COMPLETED);
        task_record.completed= true;
    }

    public entry fun delete_task(account:&signer, task_id:u64) acquires Todolist{
        let signer_address = signer::address_of(account);
        assert!(exists<Todolist>(signer_address),E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<Todolist>(signer_address);
        //assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        table::remove(&mut todo_list.tasks,task_id);
        todo_list.task_counter = todo_list.task_counter-1;
       // assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        
    }

    #[test(admin=@0x12)]
    public entry fun test_flow(admin: signer) acquires Todolist{
        account::create_account_for_test(signer::address_of(&admin));
        create_list(&admin);

        create_task(&admin, string::utf8(b"New Task"));
        let task_count = event::counter(&borrow_global<Todolist>(signer::address_of(&admin)).set_task_event);
        assert!(task_count==1,4);
        let todo_list = borrow_global<Todolist>(signer::address_of(&admin));
        assert!(todo_list.task_counter==1,5);
        let task_record = table::borrow(&todo_list.tasks,todo_list.task_counter);
        assert!(task_record.task_id==1,6);
        assert!(task_record.completed==false,7);
        assert!(task_record.content == string::utf8(b"New Task"),8);
        assert!(task_record.address==signer::address_of(&admin),9);

        complete_task(&admin, 1);
        let todo_list = borrow_global<Todolist>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks,1);
        assert!(task_record.task_id==1,10);
        assert!(task_record.completed==true,11);
        assert!(task_record.content==string::utf8(b"New Task"),12);
        assert!(task_record.address==signer::address_of(&admin),13);
    }

    #[test(admin=@0x12)]
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    public entry fun account_can_not_update_task(admin: signer) acquires Todolist{
        account::create_account_for_test(signer::address_of(&admin));
        complete_task(&admin,2);
    }

    #[test(admin=@0x12)]
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    public entry fun account_can_not_delete_task(admin: signer) acquires Todolist{
        account::create_account_for_test(signer::address_of(&admin));
        delete_task(&admin,2);
    }
}