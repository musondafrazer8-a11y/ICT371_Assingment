DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;
DROP PROCEDURE IF EXISTS reserve_workstations(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS cancel_reservation(INT);

-- Task 1
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(50) NOT NULL,
    workstations INT NOT NULL CHECK (workstations > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'RESERVED'
        CHECK (status IN ('RESERVED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT now()
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
    ('Networking Lab - Mon 08:00', 40),
    ('Linux Lab - Tue 10:00', 5),
    ('Machine Learning Lab - Wed 14:00', 0);

SELECT * FROM lab_sessions ORDER BY session_id;

-- Task 2: IF ELSIF ELSE
DO $$
DECLARE
    rec RECORD;
    v_msg TEXT;
BEGIN
    FOR rec IN SELECT session_id, session_name, available_workstations FROM lab_sessions ORDER BY session_id LOOP
        IF rec.available_workstations = 0 THEN
            v_msg := 'Session is FULL';
        ELSIF rec.available_workstations <= 5 THEN
            v_msg := 'Session is NEARLY FULL';
        ELSE
            v_msg := 'Session has ENOUGH workstations';
        END IF;
        RAISE NOTICE '% -> % (% left)', rec.session_name, v_msg, rec.available_workstations;
    END LOOP;
END $$;

-- Task 3: WHILE and numeric FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', i;
        i := i + 1;
    END LOOP;

    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number %', n;
    END LOOP;
END $$;

-- Task 4: reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(p_item_id INT, p_owner VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. It must be greater than zero.', p_qty;
    END IF;

    SELECT available_workstations INTO v_avail
    FROM lab_sessions WHERE session_id = p_item_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session with id % does not exist.', p_item_id;
    END IF;

    IF v_avail < p_qty THEN
        RAISE NOTICE 'REJECTED: % requested by % but only % available.', p_qty, p_owner, v_avail;
        RETURN;
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations - p_qty WHERE session_id = p_item_id;
    INSERT INTO reservations (session_id, lecturer, workstations)
    VALUES (p_item_id, p_owner, p_qty);

    RAISE NOTICE 'SUCCESS: reservation recorded for % (workstations %).', p_owner, p_qty;
END;
$$;

-- Task 5
CALL reserve_workstations(1, 'Dr Mulenga', 35);
CALL reserve_workstations(2, 'Mr Banda', 3);
CALL reserve_workstations(2, 'Ms Phiri', 10);   -- exceeds capacity, rejected

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- Task 6: cancel_reservation procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT session_id, workstations, status
    INTO v_item, v_qty, v_status
    FROM reservations WHERE reservation_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reservation % does not exist.', p_record_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already CANCELLED. Nothing was released.', p_record_id;
        RETURN;
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations + v_qty WHERE session_id = v_item;
    UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_record_id;

    RAISE NOTICE 'Reservation % CANCELLED and % workstations released.', p_record_id, v_qty;
END;
$$;

CALL cancel_reservation(1);   -- releases workstations
CALL cancel_reservation(1);   -- no change

SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;

-- Task 7: explicit cursor
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT session_name, available_workstations FROM lab_sessions
        WHERE available_workstations <= 5 ORDER BY available_workstations;
    v_name VARCHAR;
    v_avail INT;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO v_name, v_avail;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few workstations remaining: % (% left)', v_name, v_avail;
    END LOOP;
    CLOSE cur_low;
END $$;

-- Task 8: zero workstations with EXCEPTION
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr Test', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- Task 9: final results
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;