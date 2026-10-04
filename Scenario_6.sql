DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP PROCEDURE IF EXISTS book_seats(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS cancel_booking(INT);

-- Task 1
CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INT NOT NULL REFERENCES events(event_id),
    student_number VARCHAR(50) NOT NULL,
    seats INT NOT NULL CHECK (seats > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
        CHECK (status IN ('BOOKED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT now()
);

INSERT INTO events (event_name, available_seats) VALUES
    ('Freshers Welcome Gala', 100),
    ('Career Fair', 8),
    ('Graduation Rehearsal', 0);

SELECT * FROM events ORDER BY event_id;

-- Task 2: IF ELSIF ELSE
DO $$
DECLARE
    rec RECORD;
    v_msg TEXT;
BEGIN
    FOR rec IN SELECT event_id, event_name, available_seats FROM events ORDER BY event_id LOOP
        IF rec.available_seats = 0 THEN
            v_msg := 'Event is FULL';
        ELSIF rec.available_seats <= 10 THEN
            v_msg := 'Event is NEARLY FULL';
        ELSE
            v_msg := 'Event has PLENTY of seats';
        END IF;
        RAISE NOTICE '% -> % (% left)', rec.event_name, v_msg, rec.available_seats;
    END LOOP;
END $$;

-- Task 3: WHILE and numeric FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Booking reminder day %', i;
        i := i + 1;
    END LOOP;

    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number %', n;
    END LOOP;
END $$;

-- Task 4: book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(p_item_id INT, p_owner VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. It must be greater than zero.', p_qty;
    END IF;

    SELECT available_seats INTO v_avail
    FROM events WHERE event_id = p_item_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event with id % does not exist.', p_item_id;
    END IF;

    IF v_avail < p_qty THEN
        RAISE NOTICE 'REJECTED: % seats requested by % but only % remain.', p_qty, p_owner, v_avail;
        RETURN;
    END IF;

    UPDATE events SET available_seats = available_seats - p_qty WHERE event_id = p_item_id;
    INSERT INTO bookings (event_id, student_number, seats)
    VALUES (p_item_id, p_owner, p_qty);

    RAISE NOTICE 'SUCCESS: booking recorded for % (seats %).', p_owner, p_qty;
END;
$$;

-- Task 5
CALL book_seats(1, 'S2024001', 40);
CALL book_seats(2, 'S2024002', 5);
CALL book_seats(2, 'S2024003', 6);   -- exceeds remaining seats, rejected

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- Task 6: cancel_booking procedure
CREATE OR REPLACE PROCEDURE cancel_booking(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT event_id, seats, status
    INTO v_item, v_qty, v_status
    FROM bookings WHERE booking_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % does not exist.', p_record_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % is already CANCELLED. Seats were not released again.', p_record_id;
        RETURN;
    END IF;

    UPDATE events SET available_seats = available_seats + v_qty WHERE event_id = v_item;
    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_record_id;

    RAISE NOTICE 'Booking % CANCELLED and % seats released.', p_record_id, v_qty;
END;
$$;

CALL cancel_booking(1);   -- releases seats
CALL cancel_booking(1);   -- no change

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- Task 7: explicit cursor
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT event_name, available_seats FROM events
        WHERE available_seats <= 10 ORDER BY available_seats;
    v_name VARCHAR;
    v_avail INT;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO v_name, v_avail;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full or nearly full: % (% seats left)', v_name, v_avail;
    END LOOP;
    CLOSE cur_low;
END $$;

-- Task 8: zero seats with EXCEPTION
DO $$
BEGIN
    CALL book_seats(1, 'S9999999', 0);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- Task 9: final results
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;