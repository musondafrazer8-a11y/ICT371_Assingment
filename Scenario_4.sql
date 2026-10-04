DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP PROCEDURE IF EXISTS dispense_medicine(INT, VARCHAR, INT);
DROP PROCEDURE IF EXISTS reverse_dispensing(INT);

-- Task 1
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(50) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED'
        CHECK (status IN ('DISPENSED', 'REVERSED')),
    created_at TIMESTAMP DEFAULT now()
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol 500mg', 200),
    ('Amoxicillin 250mg', 15),
    ('Oral Rehydration Salts', 0);

SELECT * FROM medicines ORDER BY medicine_id;

-- Task 2: IF ELSIF ELSE
DO $$
DECLARE
    rec RECORD;
    v_msg TEXT;
BEGIN
    FOR rec IN SELECT medicine_id, medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF rec.stock_quantity = 0 THEN
            v_msg := 'Medicine is OUT OF STOCK';
        ELSIF rec.stock_quantity <= 20 THEN
            v_msg := 'Medicine is LOW on stock';
        ELSE
            v_msg := 'Medicine is SUFFICIENTLY stocked';
        END IF;
        RAISE NOTICE '% -> % (% left)', rec.medicine_name, v_msg, rec.stock_quantity;
    END LOOP;
END $$;

-- Task 3: WHILE and numeric FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock review day %', i;
        i := i + 1;
    END LOOP;

    FOR n IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', n;
    END LOOP;
END $$;

-- Task 4: dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(p_item_id INT, p_owner VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. It must be greater than zero.', p_qty;
    END IF;

    SELECT stock_quantity INTO v_avail
    FROM medicines WHERE medicine_id = p_item_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine with id % does not exist.', p_item_id;
    END IF;

    IF v_avail < p_qty THEN
        RAISE NOTICE 'REJECTED: % requested by % but only % in stock.', p_qty, p_owner, v_avail;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity - p_qty WHERE medicine_id = p_item_id;
    INSERT INTO dispensing_records (medicine_id, student_number, quantity)
    VALUES (p_item_id, p_owner, p_qty);

    RAISE NOTICE 'SUCCESS: dispensing recorded for % (quantity %).', p_owner, p_qty;
END;
$$;

-- Task 5
CALL dispense_medicine(1, 'S2024001', 50);
CALL dispense_medicine(2, 'S2024002', 10);
CALL dispense_medicine(2, 'S2024003', 30);   -- exceeds stock, rejected

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- Task 6: reverse_dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item INT;
    v_qty INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status
    INTO v_item, v_qty, v_status
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Record % does not exist.', p_record_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already REVERSED. Stock was not restored again.', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_item;
    UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;

    RAISE NOTICE 'Record % REVERSED and % units restored.', p_record_id, v_qty;
END;
$$;

CALL reverse_dispensing(1);   -- restores stock
CALL reverse_dispensing(1);   -- no change

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- Task 7: explicit cursor (low-stock threshold = 20)
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT medicine_name, stock_quantity FROM medicines
        WHERE stock_quantity <= 20 ORDER BY stock_quantity;
    v_name VARCHAR;
    v_avail INT;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO v_name, v_avail;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below low-stock threshold: % (% left)', v_name, v_avail;
    END LOOP;
    CLOSE cur_low;
END $$;

-- Task 8: negative quantity with EXCEPTION
DO $$
BEGIN
    CALL dispense_medicine(1, 'S9999999', -5);
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- Task 9: final results
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;