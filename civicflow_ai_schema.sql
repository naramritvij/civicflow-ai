-- =====================================================
-- CivicFlow AI - Incident Intelligence System
-- Oracle Database Schema
-- =====================================================



-- =====================================================
-- 1. ROLE TABLE
-- =====================================================

CREATE TABLE APP_ROLE (
    role_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name VARCHAR2(50) NOT NULL UNIQUE,
    role_description VARCHAR2(255)
);

-- =====================================================
-- 2. USER TABLE
-- =====================================================

CREATE TABLE APP_USER (
    user_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(150) NOT NULL UNIQUE,
    password_hash VARCHAR2(255),
    role_id NUMBER NOT NULL,
    is_active CHAR(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_role
        FOREIGN KEY (role_id)
        REFERENCES APP_ROLE(role_id)
);

-- =====================================================
-- 3. INCIDENT CATEGORY
-- =====================================================

CREATE TABLE INCIDENT_CATEGORY (
    category_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR2(100) NOT NULL UNIQUE,
    category_description VARCHAR2(255)
);

-- =====================================================
-- 4. INCIDENT SEVERITY
-- =====================================================

CREATE TABLE INCIDENT_SEVERITY (
    severity_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    severity_name VARCHAR2(50) NOT NULL UNIQUE,
    severity_level NUMBER NOT NULL UNIQUE,
    severity_description VARCHAR2(255)
);

-- =====================================================
-- 5. INCIDENT STATUS
-- =====================================================

CREATE TABLE INCIDENT_STATUS (
    status_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name VARCHAR2(50) NOT NULL UNIQUE,
    status_description VARCHAR2(255)
);

-- =====================================================
-- 6. ROUTE TABLE
-- =====================================================

CREATE TABLE TRANSIT_ROUTE (
    route_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_code VARCHAR2(20) NOT NULL UNIQUE,
    route_name VARCHAR2(100) NOT NULL,
    route_type VARCHAR2(50)
);

-- =====================================================
-- 7. STATION TABLE
-- =====================================================

CREATE TABLE STATION (
    station_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_name VARCHAR2(100) NOT NULL,
    city VARCHAR2(100),
    province VARCHAR2(50),
    is_active CHAR(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N'))
);

-- =====================================================
-- 8. RESPONSE TEAM
-- =====================================================

CREATE TABLE RESPONSE_TEAM (
    team_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_name VARCHAR2(100) NOT NULL UNIQUE,
    specialization VARCHAR2(100),
    contact_email VARCHAR2(150),
    contact_phone VARCHAR2(30),
    is_active CHAR(1) DEFAULT 'Y' CHECK (is_active IN ('Y', 'N'))
);

-- =====================================================
-- 9. MAIN INCIDENT TABLE
-- =====================================================

CREATE TABLE INCIDENT (
    incident_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_title VARCHAR2(200) NOT NULL,
    incident_description CLOB NOT NULL,

    category_id NUMBER NOT NULL,
    severity_id NUMBER NOT NULL,
    status_id NUMBER NOT NULL,

    route_id NUMBER,
    station_id NUMBER,
    assigned_team_id NUMBER,

    passenger_impact CLOB,
    recovery_action CLOB,

    start_time TIMESTAMP NOT NULL,
    estimated_recovery_time TIMESTAMP,
    actual_recovery_time TIMESTAMP,

    created_by NUMBER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,

    CONSTRAINT fk_incident_category
        FOREIGN KEY (category_id)
        REFERENCES INCIDENT_CATEGORY(category_id),

    CONSTRAINT fk_incident_severity
        FOREIGN KEY (severity_id)
        REFERENCES INCIDENT_SEVERITY(severity_id),

    CONSTRAINT fk_incident_status
        FOREIGN KEY (status_id)
        REFERENCES INCIDENT_STATUS(status_id),

    CONSTRAINT fk_incident_route
        FOREIGN KEY (route_id)
        REFERENCES TRANSIT_ROUTE(route_id),

    CONSTRAINT fk_incident_station
        FOREIGN KEY (station_id)
        REFERENCES STATION(station_id),

    CONSTRAINT fk_incident_team
        FOREIGN KEY (assigned_team_id)
        REFERENCES RESPONSE_TEAM(team_id),

    CONSTRAINT fk_incident_created_by
        FOREIGN KEY (created_by)
        REFERENCES APP_USER(user_id)
);

-- =====================================================
-- 10. INCIDENT UPDATE TABLE
-- =====================================================

CREATE TABLE INCIDENT_UPDATE (
    update_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id NUMBER NOT NULL,
    update_note CLOB NOT NULL,
    updated_status_id NUMBER,
    updated_by NUMBER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_update_incident
        FOREIGN KEY (incident_id)
        REFERENCES INCIDENT(incident_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_update_status
        FOREIGN KEY (updated_status_id)
        REFERENCES INCIDENT_STATUS(status_id),

    CONSTRAINT fk_update_user
        FOREIGN KEY (updated_by)
        REFERENCES APP_USER(user_id)
);

-- =====================================================
-- 11. AI ANALYSIS TABLE
-- =====================================================

CREATE TABLE AI_ANALYSIS (
    analysis_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id NUMBER NOT NULL,

    ai_predicted_severity VARCHAR2(50),
    ai_predicted_category VARCHAR2(100),
    ai_likely_root_cause CLOB,
    ai_recommended_action CLOB,
    ai_passenger_message CLOB,
    ai_executive_summary CLOB,
    ai_confidence_score NUMBER(5,2),

    model_name VARCHAR2(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ai_incident
        FOREIGN KEY (incident_id)
        REFERENCES INCIDENT(incident_id)
        ON DELETE CASCADE
);

-- =====================================================
-- 12. PUBLIC ALERT TABLE
-- =====================================================

CREATE TABLE PUBLIC_ALERT (
    alert_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    incident_id NUMBER NOT NULL,
    alert_title VARCHAR2(200) NOT NULL,
    alert_message CLOB NOT NULL,
    alert_status VARCHAR2(50) DEFAULT 'Published',
    published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_alert_incident
        FOREIGN KEY (incident_id)
        REFERENCES INCIDENT(incident_id)
        ON DELETE CASCADE
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_incident_status ON INCIDENT(status_id);
CREATE INDEX idx_incident_severity ON INCIDENT(severity_id);
CREATE INDEX idx_incident_category ON INCIDENT(category_id);
CREATE INDEX idx_incident_route ON INCIDENT(route_id);
CREATE INDEX idx_incident_station ON INCIDENT(station_id);
CREATE INDEX idx_incident_start_time ON INCIDENT(start_time);
CREATE INDEX idx_ai_incident ON AI_ANALYSIS(incident_id);
CREATE INDEX idx_alert_incident ON PUBLIC_ALERT(incident_id);

COMMIT;







-- =====================================================
-- ROLES
-- =====================================================

INSERT INTO APP_ROLE (role_name, role_description) VALUES ('Admin', 'System administrator');
INSERT INTO APP_ROLE (role_name, role_description) VALUES ('Operations Manager', 'Manages incidents');
INSERT INTO APP_ROLE (role_name, role_description) VALUES ('Response Team', 'Handles incident resolution');
INSERT INTO APP_ROLE (role_name, role_description) VALUES ('Passenger', 'Public user');

-- =====================================================
-- USERS
-- =====================================================

INSERT INTO APP_USER (full_name, email, role_id)
VALUES ('Ritvij Naram', 'ritvij@example.com', 1);

INSERT INTO APP_USER (full_name, email, role_id)
VALUES ('Operations Lead', 'ops@example.com', 2);

INSERT INTO APP_USER (full_name, email, role_id)
VALUES ('Field Engineer', 'engineer@example.com', 3);

-- =====================================================
-- INCIDENT CATEGORIES
-- =====================================================

INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Signal Failure');
INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Weather');
INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Mechanical Issue');
INSERT INTO INCIDENT_CATEGORY (category_name) VALUES ('Power Failure');

-- =====================================================
-- SEVERITY LEVELS
-- =====================================================

INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level)
VALUES ('Low', 1);

INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level)
VALUES ('Medium', 2);

INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level)
VALUES ('High', 3);

INSERT INTO INCIDENT_SEVERITY (severity_name, severity_level)
VALUES ('Critical', 4);

-- =====================================================
-- INCIDENT STATUS
-- =====================================================

INSERT INTO INCIDENT_STATUS (status_name) VALUES ('Open');
INSERT INTO INCIDENT_STATUS (status_name) VALUES ('In Progress');
INSERT INTO INCIDENT_STATUS (status_name) VALUES ('Resolved');

-- =====================================================
-- ROUTES
-- =====================================================

INSERT INTO TRANSIT_ROUTE (route_code, route_name)
VALUES ('L1', 'Line 1 - Northbound');

INSERT INTO TRANSIT_ROUTE (route_code, route_name)
VALUES ('L2', 'Line 2 - East-West');

-- =====================================================
-- STATIONS
-- =====================================================

INSERT INTO STATION (station_name, city, province)
VALUES ('Union Station', 'Toronto', 'ON');

INSERT INTO STATION (station_name, city, province)
VALUES ('Bloor-Yonge', 'Toronto', 'ON');

-- =====================================================
-- RESPONSE TEAMS
-- =====================================================

INSERT INTO RESPONSE_TEAM (team_name, specialization)
VALUES ('Signal Repair Team', 'Signal Systems');

INSERT INTO RESPONSE_TEAM (team_name, specialization)
VALUES ('Emergency Maintenance', 'General Repairs');

-- =====================================================
-- SAMPLE INCIDENT
-- =====================================================

INSERT INTO INCIDENT (
    incident_title,
    incident_description,
    category_id,
    severity_id,
    status_id,
    route_id,
    station_id,
    assigned_team_id,
    start_time,
    created_by
)
VALUES (
    'Signal failure near Bloor-Yonge',
    'Train delays due to signal malfunction during peak hours',
    1,
    3,
    1,
    1,
    2,
    1,
    CURRENT_TIMESTAMP,
    1
);

COMMIT;


SELECT * FROM INCIDENT;




SELECT owner, table_name
FROM all_tables
WHERE table_name = 'INCIDENT';


SELECT table_name
FROM user_tables
WHERE table_name = 'INCIDENT';




CREATE TABLE API_USAGE (
    usage_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    call_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);